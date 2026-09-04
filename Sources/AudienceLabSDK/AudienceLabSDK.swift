import Foundation

private final class AudienceLabCore {
    let apiClient = APIClient.shared
    let userProperties = UserPropertiesManager()
    lazy var tokenManager = TokenManager(apiClient: apiClient, userPropertiesManager: userProperties)
    let sessionManager = SessionManager()
    let retentionTracker = RetentionTracker()
    let offlineQueue = OfflineQueue()

    var requestResultCallback: ((Bool, String?) -> Void)?
    #if DEBUG
    var requestDebugListener: ((RequestDebugEntry) -> Void)? {
        didSet {
            apiClient.debugListener = requestDebugListener
        }
    }
    #endif

    private let keyTotalAdValue = "AudienceLabSDK_TotalAdValue"
    private let keyTotalPurchaseValue = "AudienceLabSDK_TotalPurchaseValue"

    func initialize(apiKey: String, options: AudienceLabOptions?) {
        SDKConfig.apiKey = apiKey
        SDKConfig.setInitialConfig(options: options)
        retentionTracker.prepareForLaunch()

        sessionManager.onSessionEvent = { [weak self] type, payload in
            self?.sendEvent(type: type, payload: payload, dedupeKey: nil)
        }

        sessionManager.initialize()
        offlineQueue.initialize()

        offlineQueue.setResultCallback { [weak self] success, _, _, error in
            self?.requestResultCallback?(success, error)
        }

        offlineQueue.setFlushEligibilityHandler { [weak self] in
            self?.tokenManager.hasValidToken ?? false
        }

        offlineQueue.setFlushHandler { [weak self] event, done in
            guard let self else {
                done(false)
                return
            }

            let body = self.normalizedWebhookPayload(from: event.payload)
            self.apiClient.post(path: Endpoints.webhook, body: body) { result in
                switch result {
                case .success:
                    done(true)
                case .failure:
                    done(false)
                }
            }
        }

        tokenManager.onTokenAvailable = { [weak self] _ in
            self?.sendUserMetrics()
            self?.offlineQueue.flush()
        }

        if tokenManager.hasValidToken {
            sendUserMetrics()
        }
    }

    func fetchCreativeTokenIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        tokenManager.fetchCreativeToken(completion: completion)
    }

    func verifyCreativeToken(_ token: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        tokenManager.verify(token: token, completion: completion)
    }

    func checkDataCollectionStatus(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        apiClient.get(path: Endpoints.checkDataCollectionStatus) { result in
            switch result {
            case .success(let payload):
                completion(.success(payload))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sendUserMetrics() {
        guard SDKConfig.isSDKEnabled(), SDKConfig.isMetricsEnabled() else { return }
        guard let payload = retentionTracker.updateRetentionIfNeeded() else { return }
        sendEvent(type: "retention", payload: payload, dedupeKey: nil)
    }

    func sendAdEvent(_ event: AdEvent) {
        guard SDKConfig.isSDKEnabled(), SDKConfig.isMetricsEnabled() else { return }
        sessionManager.touch()
        let totalValue = addToTotalAdValue(event.value)
        sendEvent(type: "custom.ad", payload: event.payload(totalAdValue: totalValue), dedupeKey: event.dedupeKey)
    }

    func sendPurchaseEvent(_ event: PurchaseEvent) {
        guard SDKConfig.isSDKEnabled(), SDKConfig.isMetricsEnabled() else { return }
        sessionManager.touch()
        let totalValue = event.shouldIncrementTotalValue ? addToTotalPurchaseValue(event.value) : getTotalPurchaseValue()
        sendEvent(type: "custom.purchase", payload: event.payload(totalPurchaseValue: totalValue), dedupeKey: event.dedupeKey)
    }

    func sendCustomEvent(_ event: CustomEvent) {
        guard SDKConfig.isSDKEnabled(), SDKConfig.isMetricsEnabled() else { return }
        guard !event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sessionManager.touch()
        sendEvent(type: "custom", payload: event.payload, dedupeKey: event.dedupeKey)
    }

    func sendEvent(type: String, payload: [String: Any], dedupeKey: String?) {
        let device = DeviceInfoCollector.collect()
        let envelope = EventEnvelope(
            type: type,
            eventId: UUID().uuidString.lowercased(),
            createdAt: DateUtils.nowTimestamp(),
            creativeToken: tokenManager.currentTokenOrOrganic(),
            deviceName: device.deviceName,
            deviceModel: device.deviceModel,
            osSystem: device.osVersion,
            utcOffset: DateUtils.utcOffsetHours(),
            retentionDay: retentionTracker.currentRetentionDay(),
            sdkVersion: SDKConfig.sdkVersion(),
            appVersion: SDKConfig.appVersion(),
            sdkType: SDKConfig.sdkType(),
            developmentMode: SDKConfig.isDevelopmentBuild(),
            ifv: IdentityManager.idfv(),
            ga: IdentityManager.advertisingId(),
            lat: IdentityManager.limitAdTracking(),
            wp: userProperties.whitelisted,
            bp: userProperties.blacklisted,
            dedupeKey: dedupeKey,
            payload: payload.mapValues { JSONValue.from(any: $0) }
        )

        let dictionary = envelope.toDictionary()

        if !tokenManager.hasValidToken {
            offlineQueue.enqueue(payload: dictionary, eventId: envelope.eventId, type: type)
            tokenManager.fetchCreativeToken { [weak self] _ in
                self?.offlineQueue.flush()
            }
            return
        }

        apiClient.post(path: Endpoints.webhook, body: dictionary) { [weak self] result in
            switch result {
            case .success:
                self?.requestResultCallback?(true, nil)
            case .failure(let error):
                self?.offlineQueue.enqueue(payload: dictionary, eventId: envelope.eventId, type: type)
                self?.requestResultCallback?(false, String(describing: error))
            }
        }
    }

    func getTotalAdValue() -> Double {
        CurrencyValue.double(from: storedCurrencyTotal(for: keyTotalAdValue))
    }

    func getTotalPurchaseValue() -> Double {
        CurrencyValue.double(from: storedCurrencyTotal(for: keyTotalPurchaseValue))
    }

    func addToTotalAdValue(_ value: Double) -> Double {
        let next = CurrencyValue.normalize(storedCurrencyTotal(for: keyTotalAdValue) + CurrencyValue.decimal(from: value))
        PersistenceManager.shared.set(CurrencyValue.storageString(from: next), for: keyTotalAdValue)
        return CurrencyValue.double(from: next)
    }

    func addToTotalPurchaseValue(_ value: Double) -> Double {
        let next = CurrencyValue.normalize(storedCurrencyTotal(for: keyTotalPurchaseValue) + CurrencyValue.decimal(from: value))
        PersistenceManager.shared.set(CurrencyValue.storageString(from: next), for: keyTotalPurchaseValue)
        return CurrencyValue.double(from: next)
    }

    private func storedCurrencyTotal(for key: String) -> Decimal {
        CurrencyValue.decimal(fromStored: PersistenceManager.shared.object(for: key))
    }

    private func normalizedWebhookPayload(from payload: [String: Any]) -> [String: Any] {
        var normalized = payload

        if let oldEventId = normalized["event_id"] as? String, normalized["eid"] == nil {
            normalized["eid"] = oldEventId
            normalized.removeValue(forKey: "event_id")
        }

        if let oldDedupeKey = normalized["dedupe_key"] as? String, normalized["dk"] == nil {
            normalized["dk"] = oldDedupeKey
            normalized.removeValue(forKey: "dedupe_key")
        }

        if let oldIfv = normalized["idfv"] as? String, normalized["ifv"] == nil {
            normalized["ifv"] = oldIfv
            normalized.removeValue(forKey: "idfv")
        }

        if let oldWp = normalized["user_properties_whitelisted"] as? [String: String], normalized["wp"] == nil {
            normalized["wp"] = oldWp
            normalized.removeValue(forKey: "user_properties_whitelisted")
        }

        if let oldBp = normalized["user_properties_blacklisted"] as? [String: String], normalized["bp"] == nil {
            normalized["bp"] = oldBp
            normalized.removeValue(forKey: "user_properties_blacklisted")
        }

        if let offsetString = normalized["utc_offset"] as? String {
            let sign = offsetString.hasPrefix("-") ? -1.0 : 1.0
            let cleaned = offsetString.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")
            let parts = cleaned.split(separator: ":")
            if parts.count == 2,
               let hours = Double(parts[0]),
               let minutes = Double(parts[1]) {
                normalized["utc_offset"] = sign * (hours + (minutes / 60.0))
            }
        }

        if let validToken = tokenManager.creativeToken {
            let currentToken = normalized["creativeToken"] as? String
            if currentToken == nil || currentToken?.isEmpty == true || currentToken?.hasPrefix("organic#") == true {
                normalized["creativeToken"] = validToken
            }
        } else if (normalized["creativeToken"] as? String)?.isEmpty != false {
            normalized["creativeToken"] = tokenManager.currentTokenOrOrganic()
        }

        return normalized
    }

    #if DEBUG
    func identityDebugSnapshot() -> IdentityDebugSnapshot {
        IdentityManager.debugSnapshot()
    }

    func tokenDebugSnapshot() -> TokenDebugSnapshot {
        tokenManager.debugSnapshot()
    }

    func deviceDebugSnapshot() -> DeviceDebugSnapshot {
        DeviceInfoCollector.debugSnapshot()
    }

    func queueDebugSnapshot() -> [QueueDebugEntry] {
        offlineQueue.snapshot()
    }
    #endif

    func prepareForReset() {
        requestResultCallback = nil
        #if DEBUG
        requestDebugListener = nil
        #endif
        tokenManager.onTokenAvailable = nil
        offlineQueue.setResultCallback(nil)
        offlineQueue.reset()
    }
}

@objc(AudienceLabUserPropertySet)
public enum AudienceLabUserPropertySet: Int {
    case whitelisted
    case blacklisted
}

@objc(AudienceLabSDK)
public final class AudienceLab: NSObject {
    private static var core: AudienceLabCore?
    private static let lock = NSLock()
    private static var pendingRequestResultCallback: ((Bool, String?) -> Void)?
    #if DEBUG
    private static var pendingRequestDebugListener: ((RequestDebugEntry) -> Void)?
    #endif

    @objc
    public static var isInitialized: Bool {
        core != nil
    }

    @objc(initializeWithApiKey:options:)
    public static func initialize(apiKey: String, options: AudienceLabOptions? = nil) {
        guard !apiKey.isEmpty else {
            Logger.debug("Initialization aborted: empty API key")
            return
        }

        lock.lock()
        defer { lock.unlock() }

        if core != nil {
            SDKConfig.setInitialConfig(options: options)
            Logger.debug("AudienceLabSDK already initialized, configuration re-applied")
            return
        }

        let core = AudienceLabCore()
        core.initialize(apiKey: apiKey, options: options)
        core.requestResultCallback = pendingRequestResultCallback
        #if DEBUG
        core.requestDebugListener = pendingRequestDebugListener
        #endif
        self.core = core

        core.fetchCreativeTokenIfNeeded { _ in
            core.offlineQueue.flush()
        }
    }

    @objc
    public static func getCreativeToken() -> String? {
        core?.tokenManager.creativeToken
    }

    @objc
    public static func isDevelopmentMode() -> Bool {
        SDKConfig.isDevelopmentBuild()
    }

    @objc
    public static func setSDKEnabled(_ enabled: Bool) {
        SDKConfig.setSDKEnabled(enabled)
    }

    @objc
    public static func isSDKEnabled() -> Bool {
        SDKConfig.isSDKEnabled()
    }

    @objc
    public static func setMetricsCollectionEnabled(_ enabled: Bool) {
        SDKConfig.setMetricsEnabled(enabled)
    }

    @objc
    public static func isMetricsCollectionEnabled() -> Bool {
        SDKConfig.isMetricsEnabled()
    }

    @objc
    public static func setDebugEnabled(_ enabled: Bool) {
        SDKConfig.setDebugEnabled(enabled)
    }

    @objc
    public static func isDebugEnabled() -> Bool {
        SDKConfig.isDebugEnabled()
    }

    @objc
    public static func getSDKVersion() -> String {
        SDKConfig.sdkVersion()
    }

    @objc
    public static func getAppVersion() -> String {
        SDKConfig.appVersion()
    }

    @objc
    public static func getRuntimeVersion() -> String {
        "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }

    @objc
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }

        core?.prepareForReset()
        core = nil
        SDKConfig.apiKey = nil
        PersistenceManager.shared.removeAll(withPrefix: "AudienceLabSDK_")
    }

    @objc
    public static func isIdentitySettled() -> Bool {
        IdentityManager.isSettled()
    }

    @objc
    public static func getRevenueCatAttributes() -> [String: String] {
        revenueCatAttributes(from: IdentityManager.idfv())
    }

    static func revenueCatAttributes(from ifv: String?) -> [String: String] {
        guard let value = ifv?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return [:]
        }
        return ["audienceLabId": value]
    }

    @objc
    public static func sendAdEvent(adId: String, name: String, source: String, watchTime: Double, reward: Bool, mediaSource: String, channel: String, value: Double, currency: String, dedupeKey: String? = nil) {
        let event = AdEvent(adId: adId, name: name, source: source, watchTime: watchTime, reward: reward, mediaSource: mediaSource, channel: channel, value: value, currency: currency, dedupeKey: dedupeKey)
        core?.sendAdEvent(event)
    }

    @objc
    public static func sendPurchaseEvent(itemId: String, itemName: String, value: Double, currency: String, status: String, transactionId: String? = nil, dedupeKey: String? = nil) {
        let event = PurchaseEvent(itemId: itemId, itemName: itemName, value: value, currency: currency, status: status, transactionId: transactionId, dedupeKey: dedupeKey)
        core?.sendPurchaseEvent(event)
    }

    @objc
    public static func sendCustomEvent(name: String, params: NSDictionary, dedupeKey: String? = nil) {
        let swiftParams = params as? [String: Any] ?? [:]
        let event = CustomEvent(name: name, params: swiftParams, dedupeKey: dedupeKey)
        core?.sendCustomEvent(event)
    }

    @objc
    @discardableResult
    public static func setUserProperty(key: String, value: String, set: AudienceLabUserPropertySet) -> Bool {
        return core?.userProperties.set(key: key, value: value, in: set) ?? false
    }

    @objc
    public static func unsetUserProperty(key: String, set: AudienceLabUserPropertySet) {
        core?.userProperties.unset(key: key, from: set)
    }

    @objc
    public static func clearUserProperties(_ set: AudienceLabUserPropertySet) {
        core?.userProperties.clear(set)
    }

    @objc
    public static func getWhitelistedUserProperties() -> NSDictionary {
        (core?.userProperties.whitelisted ?? [:]) as NSDictionary
    }

    @objc
    public static func getBlacklistedUserProperties() -> NSDictionary {
        (core?.userProperties.blacklisted ?? [:]) as NSDictionary
    }

    /// Sets the IDFA (Identifier for Advertisers) manually.
    ///
    /// Can be called before or after ``initialize(apiKey:options:)``. When called
    /// before, the ID is included in the very first token fetch and event dispatch.
    @objc
    public static func setAdvertisingId(_ idfa: String) {
        IdentityManager.setAdvertisingId(idfa)
    }

    @objc
    public static func clearAdvertisingId() {
        IdentityManager.clearAdvertisingId()
    }

    @objc
    public static func getSessionId() -> String? {
        core?.sessionManager.sessionId
    }

    @objc
    public static func getSessionIndex() -> Int {
        core?.sessionManager.sessionIndex ?? 0
    }

    @objc
    public static func getQueueSize() -> Int {
        core?.offlineQueue.getQueueSize() ?? 0
    }

    public static func setRequestResultCallback(_ callback: ((Bool, String?) -> Void)?) {
        pendingRequestResultCallback = callback
        core?.requestResultCallback = callback
    }

    @objc
    public static func clearRequestResultCallback() {
        pendingRequestResultCallback = nil
        core?.requestResultCallback = nil
    }

    #if DEBUG
    public static func setRequestDebugListener(_ listener: ((RequestDebugEntry) -> Void)?) {
        pendingRequestDebugListener = listener
        core?.requestDebugListener = listener
    }

    @objc
    public static func clearRequestDebugListener() {
        pendingRequestDebugListener = nil
        core?.requestDebugListener = nil
    }

    public static func getIdentityDebugSnapshot() -> IdentityDebugSnapshot {
        core?.identityDebugSnapshot() ?? IdentityManager.debugSnapshot()
    }

    public static func getTokenDebugSnapshot() -> TokenDebugSnapshot {
        core?.tokenDebugSnapshot() ?? TokenDebugSnapshot(
            hasValidToken: false,
            creativeTokenPreview: nil,
            lastFetchStatus: "idle",
            lastAttemptAtMillis: nil,
            attemptCount: 0,
            nextRetryAtMillis: nil
        )
    }

    public static func getDeviceDebugSnapshot() -> DeviceDebugSnapshot {
        core?.deviceDebugSnapshot() ?? DeviceInfoCollector.debugSnapshot()
    }

    public static func getQueueDebugSnapshot() -> [QueueDebugEntry] {
        core?.queueDebugSnapshot() ?? []
    }
    #endif

    @objc(checkDataCollectionStatusWithCompletion:)
    public static func checkDataCollectionStatus(_ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let core else {
            completion(nil, notInitializedError())
            return
        }

        core.checkDataCollectionStatus { result in
            switch result {
            case .success(let payload):
                completion(payload as NSDictionary, nil)
            case .failure(let error):
                completion(nil, error as NSError)
            }
        }
    }

    @objc(verifyCreativeToken:completion:)
    public static func verifyCreativeToken(_ token: String, completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard let core else {
            completion(nil, notInitializedError())
            return
        }

        core.verifyCreativeToken(token) { result in
            switch result {
            case .success(let payload):
                completion(payload as NSDictionary, nil)
            case .failure(let error):
                completion(nil, error as NSError)
            }
        }
    }

    private static func notInitializedError() -> NSError {
        NSError(
            domain: "AudienceLabSDK",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "AudienceLabSDK is not initialized"]
        )
    }
}
