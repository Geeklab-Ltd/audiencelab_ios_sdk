import Foundation
import Network

struct QueuedEvent {
    let payload: [String: Any]
    let queuedAt: TimeInterval
    let eventId: String
    let type: String

    init(payload: [String: Any], queuedAt: TimeInterval = Date().timeIntervalSince1970 * 1000, eventId: String, type: String) {
        self.payload = payload
        self.queuedAt = queuedAt
        self.eventId = eventId
        self.type = type
    }

    init?(dictionary: [String: Any]) {
        guard
            let payload = dictionary["payload"] as? [String: Any],
            let queuedAt = dictionary["queued_at"] as? TimeInterval,
            let eventId = dictionary["event_id"] as? String,
            let type = dictionary["type"] as? String
        else {
            return nil
        }
        self.payload = payload
        self.queuedAt = queuedAt
        self.eventId = eventId
        self.type = type
    }

    func toDictionary() -> [String: Any] {
        [
            "payload": payload,
            "queued_at": queuedAt,
            "event_id": eventId,
            "type": type
        ]
    }
}

final class OfflineQueue {
    typealias FlushHandler = (QueuedEvent, @escaping (Bool) -> Void) -> Void
    typealias ResultCallback = (_ success: Bool, _ type: String, _ eventId: String, _ error: String?) -> Void
    typealias FlushEligibilityHandler = () -> Bool

    private let storageKey = "AudienceLabSDK_OfflineQueue"
    private let maxQueueSize = 200
    private let maxAgeMs: TimeInterval = 24 * 60 * 60 * 1000
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "AudienceLabSDK.NetworkMonitor")
    private let serialQueue = DispatchQueue(label: "AudienceLabSDK.OfflineQueue")

    private var queue: [QueuedEvent] = []
    private var flushHandler: FlushHandler?
    private var flushEligibilityHandler: FlushEligibilityHandler?
    private var resultCallback: ResultCallback?
    private var isFlushing = false
    private var connected = true

    func initialize() {
        let savedEvents = PersistenceManager.shared.array(for: storageKey) ?? []
        queue = savedEvents.compactMap(QueuedEvent.init(dictionary:))
        pruneStale()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.connected = path.status == .satisfied
            if path.status == .satisfied {
                self?.flush()
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func setFlushHandler(_ handler: @escaping FlushHandler) {
        flushHandler = handler
    }

    func setResultCallback(_ callback: ResultCallback?) {
        resultCallback = callback
    }

    func setFlushEligibilityHandler(_ handler: @escaping FlushEligibilityHandler) {
        flushEligibilityHandler = handler
    }

    func enqueue(payload: [String: Any], eventId: String, type: String) {
        serialQueue.async {
            self.pruneStale()
            if self.queue.count >= self.maxQueueSize {
                self.queue.removeFirst()
            }
            self.queue.append(QueuedEvent(payload: payload, eventId: eventId, type: type))
            self.persist()
        }
    }

    func flush() {
        serialQueue.async {
            let canFlush = self.flushEligibilityHandler?() ?? true
            guard !self.isFlushing, self.connected, !self.queue.isEmpty, canFlush, let flushHandler = self.flushHandler else { return }
            self.isFlushing = true
            self.pruneStale()
            let pending = self.queue
            var failed: [QueuedEvent] = []
            let group = DispatchGroup()

            for event in pending {
                group.enter()
                flushHandler(event) { success in
                    self.serialQueue.async {
                        if success {
                            self.resultCallback?(true, event.type, event.eventId, nil)
                        } else {
                            failed.append(event)
                            self.resultCallback?(false, event.type, event.eventId, "Flush failed")
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: self.serialQueue) {
                self.queue = failed
                self.persist()
                self.isFlushing = false
            }
        }
    }

    func getQueueSize() -> Int {
        serialQueue.sync { queue.count }
    }

    #if DEBUG
    func snapshot() -> [QueueDebugEntry] {
        serialQueue.sync {
            queue.map { event in
                QueueDebugEntry(
                    requestName: event.type == "custom" ? buildCustomRequestName(from: event.payload) : event.type,
                    eventId: event.eventId,
                    type: event.type,
                    payload: DebugUtilities.jsonString(event.payload),
                    queuedAtMillis: NSNumber(value: event.queuedAt)
                )
            }
        }
    }
    #endif

    func reset() {
        serialQueue.sync {
            queue.removeAll()
            persist()
            isFlushing = false
        }
        monitor.cancel()
    }

    private func pruneStale() {
        let now = Date().timeIntervalSince1970 * 1000
        queue = queue.filter { now - $0.queuedAt < maxAgeMs }
    }

    private func persist() {
        let serialized = queue.map { $0.toDictionary() }
        PersistenceManager.shared.set(serialized, for: storageKey)
    }

    private func buildCustomRequestName(from payload: [String: Any]) -> String {
        guard let nestedPayload = payload["payload"] as? [String: Any],
              let eventName = nestedPayload["en"] as? String,
              !eventName.isEmpty else {
            return "custom"
        }
        return "custom:\(eventName)"
    }
}
