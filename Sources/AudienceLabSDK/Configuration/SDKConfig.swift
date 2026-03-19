import Foundation

enum SDKConfig {
    private static let sdkVersionValue = "1.1.11"
    private static let sdkTypeValue = "native_ios"
    private static let keySDKEnabled = "AudienceLabSDK_Enabled"
    private static let keyMetricsEnabled = "AudienceLabSDK_MetricsEnabled"
    private static let keyDebugEnabled = "AudienceLabSDK_DebugEnabled"
    private static let keyDevelopmentMode = "AudienceLabSDK_DevelopmentMode"
    private static let keyAppVersion = "AudienceLabSDK_AppVersion"

    static var apiKey: String?

    static func setInitialConfig(options: AudienceLabOptions?) {
        if let options {
            setSDKEnabled(options.isSDKEnabled)
            setMetricsEnabled(options.isMetricsEnabled)
            setDebugEnabled(options.isDebugEnabled)
            setDevelopmentMode(options.isDevelopmentMode)
            if let version = options.appVersion, !version.isEmpty {
                setAppVersion(version)
            } else {
                PersistenceManager.shared.removeObject(for: keyAppVersion)
            }
        } else if PersistenceManager.shared.object(for: keyDevelopmentMode) == nil {
            setDevelopmentMode(defaultDevelopmentMode())
        }
    }

    static func setSDKEnabled(_ enabled: Bool) {
        PersistenceManager.shared.set(enabled, for: keySDKEnabled)
    }

    static func isSDKEnabled() -> Bool {
        PersistenceManager.shared.bool(for: keySDKEnabled, defaultValue: true)
    }

    static func setMetricsEnabled(_ enabled: Bool) {
        PersistenceManager.shared.set(enabled, for: keyMetricsEnabled)
    }

    static func isMetricsEnabled() -> Bool {
        PersistenceManager.shared.bool(for: keyMetricsEnabled, defaultValue: true)
    }

    static func setDebugEnabled(_ enabled: Bool) {
        PersistenceManager.shared.set(enabled, for: keyDebugEnabled)
    }

    static func isDebugEnabled() -> Bool {
        PersistenceManager.shared.bool(for: keyDebugEnabled, defaultValue: false)
    }

    static func setDevelopmentMode(_ enabled: Bool) {
        PersistenceManager.shared.set(enabled, for: keyDevelopmentMode)
    }

    static func isDevelopmentBuild() -> Bool {
        PersistenceManager.shared.bool(for: keyDevelopmentMode, defaultValue: defaultDevelopmentMode())
    }

    static func setAppVersion(_ version: String) {
        PersistenceManager.shared.set(version, for: keyAppVersion)
    }

    static func appVersion() -> String {
        if let explicit = PersistenceManager.shared.string(for: keyAppVersion), !explicit.isEmpty {
            return explicit
        }
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !bundleVersion.isEmpty {
            return bundleVersion
        }
        return "unknown"
    }

    static func sdkVersion() -> String {
        sdkVersionValue
    }

    static func sdkType() -> String {
        sdkTypeValue
    }

    static func defaultDevelopmentMode() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
