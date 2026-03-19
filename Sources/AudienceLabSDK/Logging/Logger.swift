import Foundation
import os.log

enum Logger {
    private static let subsystem = "app.geeklab.audiencelab.ios"
    private static let category = "AudienceLabSDK"
    private static let log = OSLog(subsystem: subsystem, category: category)

    static func debug(_ message: String) {
        guard SDKConfig.isDebugEnabled() else { return }
        os_log("%{public}@", log: log, type: .debug, message)
    }
}
