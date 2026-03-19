import Foundation
import UIKit

final class IdentityManager {
    private static let keyAdvertisingId = "AudienceLabSDK_AdvertisingId"
    private static let keyLimitAdTracking = "AudienceLabSDK_LimitAdTracking"

    static func idfv() -> String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    static func advertisingId() -> String? {
        PersistenceManager.shared.string(for: keyAdvertisingId)
    }

    static func setAdvertisingId(_ id: String) {
        PersistenceManager.shared.set(id, for: keyAdvertisingId)
    }

    static func clearAdvertisingId() {
        PersistenceManager.shared.set(nil, for: keyAdvertisingId)
    }

    static func limitAdTracking() -> Bool? {
        guard let raw = PersistenceManager.shared.object(for: keyLimitAdTracking) as? Bool else {
            return nil
        }
        return raw
    }

    static func setLimitAdTracking(_ value: Bool?) {
        PersistenceManager.shared.set(value, for: keyLimitAdTracking)
    }

    static func isSettled() -> Bool {
        true
    }

    #if DEBUG
    static func debugSnapshot() -> IdentityDebugSnapshot {
        let idfv = idfv()
        let advertisingId = advertisingId()
        let lat = limitAdTracking()

        return IdentityDebugSnapshot(
            settled: true,
            idfvAvailable: idfv?.isEmpty == false,
            advertisingIdAvailable: advertisingId?.isEmpty == false,
            idfvPreview: DebugUtilities.mask(idfv),
            advertisingIdPreview: DebugUtilities.mask(advertisingId),
            limitAdTracking: lat.map(NSNumber.init(value:))
        )
    }
    #endif
}
