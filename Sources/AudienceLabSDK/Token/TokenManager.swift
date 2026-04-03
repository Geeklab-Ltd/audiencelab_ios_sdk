import Foundation

final class TokenManager {
    private let keyCreativeToken = "AudienceLabSDK_CreativeToken"
    private let initialDelayMs: Int = 5000
    private let maxDelayMs: Int = 300_000
    private let maxAttempts: Int = 10

    private let apiClient: APIClient
    private let userPropertiesManager: UserPropertiesManager
    private(set) var creativeToken: String?
    private(set) var lastFetchStatus: String = "idle"
    private(set) var lastAttemptAtMillis: TimeInterval?
    private(set) var attemptCount: Int = 0
    private(set) var nextRetryAtMillis: TimeInterval?
    var onTokenAvailable: ((String) -> Void)?

    private var isFetching = false
    private var waiters: [(Result<String, Error>) -> Void] = []
    private let stateLock = NSLock()

    init(apiClient: APIClient, userPropertiesManager: UserPropertiesManager) {
        self.apiClient = apiClient
        self.userPropertiesManager = userPropertiesManager
        self.creativeToken = normalizeValidToken(PersistenceManager.shared.string(for: keyCreativeToken))
        if creativeToken != nil {
            lastFetchStatus = "token_available"
        }
    }

    func fetchCreativeToken(completion: @escaping (Result<String, Error>) -> Void) {
        if let cached = normalizeValidToken(creativeToken) {
            lastFetchStatus = "token_available"
            completion(.success(cached))
            return
        }

        stateLock.lock()
        waiters.append(completion)
        let shouldStartFetch = !isFetching
        if shouldStartFetch {
            isFetching = true
        }
        stateLock.unlock()

        guard shouldStartFetch else { return }
        fetchWithRetry(attempt: 1, delayMs: initialDelayMs)
    }

    func verify(token: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        apiClient.post(path: Endpoints.verifyToken, body: ["token": token]) { result in
            switch result {
            case .success(let payload):
                completion(.success(payload))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func currentTokenOrOrganic() -> String {
        if let token = normalizeValidToken(creativeToken) {
            return token
        }
        return "organic#ios"
    }

    var hasValidToken: Bool {
        normalizeValidToken(creativeToken) != nil
    }

    #if DEBUG
    func debugSnapshot() -> TokenDebugSnapshot {
        TokenDebugSnapshot(
            hasValidToken: hasValidToken,
            creativeTokenPreview: DebugUtilities.mask(creativeToken),
            lastFetchStatus: lastFetchStatus,
            lastAttemptAtMillis: lastAttemptAtMillis.map(NSNumber.init(value:)),
            attemptCount: attemptCount,
            nextRetryAtMillis: nextRetryAtMillis.map(NSNumber.init(value:))
        )
    }
    #endif

    private func fetchWithRetry(attempt: Int, delayMs: Int) {
        lastFetchStatus = "fetching"
        lastAttemptAtMillis = Date().timeIntervalSince1970 * 1000
        attemptCount = attempt
        nextRetryAtMillis = nil
        let payload = fetchTokenPayload()

        apiClient.post(path: Endpoints.fetchToken, body: payload) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let response):
                guard let token = self.normalizeValidToken(response["token"] as? String) else {
                    self.lastFetchStatus = "invalid_token"
                    self.finishFetch(.failure(APIClientError.noData))
                    return
                }

                self.setToken(token)
                self.mergeServerWhitelistedProperties(from: response)
                self.lastFetchStatus = "ok"
                self.attemptCount = 0
                self.nextRetryAtMillis = nil
                self.finishFetch(.success(token))

            case .failure(let error):
                guard attempt < self.maxAttempts else {
                    self.lastFetchStatus = "max_attempts"
                    self.nextRetryAtMillis = nil
                    self.finishFetch(.failure(error))
                    return
                }

                let jitter = Int(Double(delayMs) * Double.random(in: 0...0.3))
                let wait = min(delayMs + jitter, self.maxDelayMs)
                self.lastFetchStatus = self.readableStatus(for: error)
                self.nextRetryAtMillis = Date().timeIntervalSince1970 * 1000 + Double(wait)
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(wait)) {
                    self.fetchWithRetry(attempt: attempt + 1, delayMs: min(delayMs * 2, self.maxDelayMs))
                }
            }
        }
    }

    func fetchTokenPayload(device: DeviceInfo = DeviceInfoCollector.collect()) -> [String: Any] {
        var data: [String: Any] = [
            "os_system": device.osVersion,
            "device_model": device.deviceModel,
            "device_name": device.deviceName,
            "timezone": DateUtils.timezoneIdentifier(),
            "dpi": Int(device.dpi.rounded()),
            "window_width": device.screenWidth,
            "window_height": device.screenHeight,
            "low_battery_level": device.lowBattery
        ]

        if !device.gpuVersion.isEmpty {
            data["gpu_version"] = device.gpuVersion
        }

        if !device.gpuRenderer.isEmpty {
            data["gpu_rendered"] = device.gpuRenderer
        }

        if !device.gpuVendor.isEmpty {
            data["gpu_vendor"] = device.gpuVendor
        }

        if let gpuContent = device.gpuContent, !gpuContent.isEmpty {
            data["gpu_content"] = gpuContent
        }

        var payload: [String: Any] = [
            "data": data,
            "type": "device-metrics",
            "created_at": DateUtils.nowTimestamp(),
            "sdk_version": SDKConfig.sdkVersion(),
            "sdk_type": SDKConfig.sdkType(),
            "app_version": SDKConfig.appVersion(),
            "dev": SDKConfig.isDevelopmentBuild(),
            "wp": userPropertiesManager.whitelisted,
            "bp": userPropertiesManager.blacklisted
        ]

        if let ifv = IdentityManager.idfv(), !ifv.isEmpty {
            payload["ifv"] = ifv
        }

        if let idfa = IdentityManager.advertisingId(), !idfa.isEmpty {
            payload["ga"] = idfa
        }

        if let lat = IdentityManager.limitAdTracking() {
            payload["lat"] = lat
        }

        return payload
    }

    func mergeServerWhitelistedProperties(from response: [String: Any]) {
        if let wp = response["wp"] as? [String: String] {
            userPropertiesManager.mergeServerWhitelistedProperties(wp)
            return
        }

        if let wpRaw = response["wp"] as? [String: Any] {
            let normalized = wpRaw.reduce(into: [String: String]()) { partial, element in
                let (key, value) = element
                switch value {
                case let string as String:
                    partial[key] = string
                case let number as NSNumber:
                    partial[key] = number.stringValue
                default:
                    partial[key] = String(describing: value)
                }
            }
            userPropertiesManager.mergeServerWhitelistedProperties(normalized)
            return
        }

        if let fallback = response["whitelisted_properties"] as? [String: String] {
            userPropertiesManager.mergeServerWhitelistedProperties(fallback)
        }
    }

    private func finishFetch(_ result: Result<String, Error>) {
        stateLock.lock()
        let callbacks = waiters
        waiters.removeAll()
        isFetching = false
        stateLock.unlock()

        DispatchQueue.main.async {
            callbacks.forEach { $0(result) }
        }
    }

    private func setToken(_ token: String) {
        let normalized = normalizeValidToken(token)
        let previous = creativeToken
        creativeToken = normalized
        PersistenceManager.shared.set(normalized, for: keyCreativeToken)
        if let normalized, normalized != previous {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onTokenAvailable?(normalized)
            }
        }
    }

    private func normalizeValidToken(_ token: String?) -> String? {
        let normalized = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return nil
        }
        if normalized.caseInsensitiveCompare("bin") == .orderedSame {
            return nil
        }
        return normalized
    }

    private func readableStatus(for error: APIClientError) -> String {
        switch error {
        case .apiKeyMissing:
            return "api_key_missing"
        case .noData:
            return "no_data"
        case .invalidURL:
            return "invalid_url"
        case .transport:
            return "transport_error"
        case .server(let statusCode, _):
            return "server_\(statusCode)"
        }
    }
}
