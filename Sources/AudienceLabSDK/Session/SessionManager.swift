import Foundation
import UIKit

final class SessionManager {
    private let keySessionId = "AudienceLabSDK_SessionId"
    private let keySessionIndex = "AudienceLabSDK_SessionIndex"
    private let keySessionStartSeconds = "AudienceLabSDK_SessionStartSeconds"
    private let keyLastActiveSeconds = "AudienceLabSDK_LastActiveSeconds"
    private let keySessionDurationSeconds = "AudienceLabSDK_SessionDurationSeconds"
    private let keySessionSegmentStartSeconds = "AudienceLabSDK_SessionSegmentStartSeconds"
    private let sessionTimeoutSeconds: TimeInterval = 1_800
    private let clock: Clock
    private let notificationCenter: NotificationCenter

    private var observers: [NSObjectProtocol] = []

    private(set) var sessionId: String?
    private(set) var sessionIndex: Int = 0

    private var sessionActive = false
    private var sessionStartSeconds: TimeInterval = 0
    private var accumulatedDurationSeconds: TimeInterval = 0
    private var currentSegmentStartSeconds: TimeInterval?
    private var lastPauseSeconds: TimeInterval?

    var onSessionEvent: ((String, [String: Any]) -> Void)?

    init(clock: Clock = SystemClock(), notificationCenter: NotificationCenter = .default) {
        self.clock = clock
        self.notificationCenter = notificationCenter
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    func initialize() {
        loadSessionState()
        startSessionIfNeeded(at: nowSeconds())
        setupLifecycleObservers()
    }

    func touch() {
        let now = nowSeconds()

        if !sessionActive {
            startSessionIfNeeded(at: now)
            return
        }

        if let lastActive = lastActiveSeconds(), now - lastActive > sessionTimeoutSeconds {
            endSession(reason: "timeout", at: lastActive, includeCurrentSegment: true)
            startNewSession(at: now)
            return
        }

        if currentSegmentStartSeconds == nil {
            currentSegmentStartSeconds = now
        }

        updateLastActive(now)
    }

    private func nowSeconds() -> TimeInterval {
        clock.now.timeIntervalSince1970
    }

    private func loadSessionState() {
        sessionId = PersistenceManager.shared.string(for: keySessionId)
        sessionIndex = PersistenceManager.shared.integer(for: keySessionIndex, defaultValue: 0)
        sessionStartSeconds = PersistenceManager.shared.double(for: keySessionStartSeconds, defaultValue: 0)
        accumulatedDurationSeconds = PersistenceManager.shared.double(for: keySessionDurationSeconds, defaultValue: 0)
        let storedSegmentStart = PersistenceManager.shared.double(for: keySessionSegmentStartSeconds, defaultValue: 0)
        currentSegmentStartSeconds = storedSegmentStart > 0 ? storedSegmentStart : nil
    }

    private func persistSessionState() {
        PersistenceManager.shared.set(sessionId, for: keySessionId)
        PersistenceManager.shared.set(sessionIndex, for: keySessionIndex)
        PersistenceManager.shared.set(sessionStartSeconds, for: keySessionStartSeconds)
        PersistenceManager.shared.set(accumulatedDurationSeconds, for: keySessionDurationSeconds)
        PersistenceManager.shared.set(currentSegmentStartSeconds, for: keySessionSegmentStartSeconds)
    }

    private func startSessionIfNeeded(at now: TimeInterval) {
        let hasExistingSession = (sessionId?.isEmpty == false) && sessionStartSeconds > 0
        let gapSeconds: TimeInterval

        if let lastActive = lastActiveSeconds() {
            gapSeconds = now - lastActive
        } else {
            gapSeconds = .greatestFiniteMagnitude
        }

        if !hasExistingSession {
            startNewSession(at: now)
            return
        }

        if gapSeconds > sessionTimeoutSeconds {
            endPreviousSession(reason: "timeout", lastActive: lastActiveSeconds())
            startNewSession(at: now)
            return
        }

        sessionActive = true
        currentSegmentStartSeconds = now
        updateLastActive(now)
    }

    private func startNewSession(at startTime: TimeInterval) {
        sessionId = UUID().uuidString.lowercased()
        sessionIndex += 1
        sessionStartSeconds = startTime
        accumulatedDurationSeconds = 0
        currentSegmentStartSeconds = startTime
        sessionActive = true
        lastPauseSeconds = nil

        persistSessionState()
        updateLastActive(startTime)
        emitSessionEvent(action: "start", reason: nil, durationSeconds: nil)
    }

    private func endPreviousSession(reason: String, lastActive: TimeInterval?) {
        guard sessionId != nil else { return }
        let duration = max(0, Int(reconstructedAccumulatedDuration(lastActive: lastActive).rounded()))
        emitSessionEvent(action: "end", reason: reason, durationSeconds: duration)
    }

    private func endSession(reason: String, at endTime: TimeInterval, includeCurrentSegment: Bool) {
        guard sessionActive else { return }

        if includeCurrentSegment {
            saveCurrentSegmentDuration(until: endTime)
        }

        let duration = max(0, Int(accumulatedDurationSeconds.rounded()))
        emitSessionEvent(action: "end", reason: reason, durationSeconds: duration)

        sessionActive = false
        currentSegmentStartSeconds = nil
        lastPauseSeconds = nil

        persistSessionState()
        updateLastActive(endTime)
    }

    private func reconstructedAccumulatedDuration(lastActive: TimeInterval?) -> TimeInterval {
        guard let lastActive, let segmentStart = currentSegmentStartSeconds else {
            return accumulatedDurationSeconds
        }

        let segmentDuration = max(0, lastActive - segmentStart)
        return accumulatedDurationSeconds + segmentDuration
    }

    private func saveCurrentSegmentDuration(until endTime: TimeInterval) {
        guard let segmentStart = currentSegmentStartSeconds else { return }

        let segmentDuration = max(0, endTime - segmentStart)
        accumulatedDurationSeconds += segmentDuration
        currentSegmentStartSeconds = nil
        persistSessionState()
    }

    private func emitSessionEvent(action: String, reason: String?, durationSeconds: Int?) {
        guard let sessionId else { return }

        var payload: [String: Any] = [
            "a": action,
            "sid": sessionId,
            "si": sessionIndex
        ]

        if let reason {
            payload["r"] = reason
        }

        if let durationSeconds {
            payload["sd"] = durationSeconds
        }

        onSessionEvent?("session", payload)
    }

    private func lastActiveSeconds() -> TimeInterval? {
        let raw = PersistenceManager.shared.double(for: keyLastActiveSeconds, defaultValue: 0)
        return raw > 0 ? raw : nil
    }

    private func updateLastActive(_ value: TimeInterval) {
        PersistenceManager.shared.set(value, for: keyLastActiveSeconds)
    }

    func appDidEnterBackground() {
        let now = nowSeconds()
        saveCurrentSegmentDuration(until: now)
        lastPauseSeconds = now
        updateLastActive(now)
    }

    func appDidBecomeActive() {
        let now = nowSeconds()

        if let lastPauseSeconds {
            let gap = now - lastPauseSeconds
            if gap > sessionTimeoutSeconds {
                endSession(reason: "background_timeout", at: now, includeCurrentSegment: false)
                startNewSession(at: now)
                return
            }
        }

        if !sessionActive {
            startSessionIfNeeded(at: now)
            return
        }

        currentSegmentStartSeconds = now
        lastPauseSeconds = nil
        updateLastActive(now)
    }

    func appWillTerminate() {
        endSession(reason: "quit", at: nowSeconds(), includeCurrentSegment: true)
    }

    private func setupLifecycleObservers() {
        guard observers.isEmpty else { return }

        let didEnterBackground = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appDidEnterBackground()
        }

        let didBecomeActive = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appDidBecomeActive()
        }

        let willTerminate = notificationCenter.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appWillTerminate()
        }

        observers.append(didEnterBackground)
        observers.append(didBecomeActive)
        observers.append(willTerminate)
    }
}
