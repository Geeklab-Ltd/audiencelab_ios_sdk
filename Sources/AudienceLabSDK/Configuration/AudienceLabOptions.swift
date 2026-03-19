import Foundation

@objcMembers
public final class AudienceLabOptions: NSObject {
    public var isSDKEnabled: Bool
    public var isMetricsEnabled: Bool
    public var isDebugEnabled: Bool
    public var isDevelopmentMode: Bool
    public var appVersion: String?

    public override init() {
        self.isSDKEnabled = true
        self.isMetricsEnabled = true
        self.isDebugEnabled = false
        #if DEBUG
        self.isDevelopmentMode = true
        #else
        self.isDevelopmentMode = false
        #endif
        super.init()
    }
}
