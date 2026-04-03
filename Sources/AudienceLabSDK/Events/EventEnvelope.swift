import Foundation

struct EventEnvelope {
    let type: String
    let eventId: String
    let createdAt: String
    let creativeToken: String
    let deviceName: String
    let deviceModel: String
    let osSystem: String
    let utcOffset: Double
    let retentionDay: Int?
    let sdkVersion: String
    let appVersion: String
    let sdkType: String
    let developmentMode: Bool
    let ifv: String?
    let ga: String?
    let lat: Bool?
    let wp: [String: String]
    let bp: [String: String]
    let dedupeKey: String?
    let payload: [String: JSONValue]

    func toDictionary() -> [String: Any] {
        var dictionary: [String: Any] = [
            "type": type,
            "eid": eventId,
            "created_at": createdAt,
            "creativeToken": creativeToken,
            "device_name": deviceName,
            "device_model": deviceModel,
            "os_system": osSystem,
            "utc_offset": utcOffset,
            "sdk_version": sdkVersion,
            "app_version": appVersion,
            "sdk_type": sdkType,
            "dev": developmentMode,
            "wp": wp,
            "bp": bp,
            "payload": payload.mapValues { $0.toAny() }
        ]

        if let retentionDay {
            dictionary["retention_day"] = retentionDay
        }
        if let ifv {
            dictionary["ifv"] = ifv
        }
        if let ga, !ga.isEmpty {
            dictionary["ga"] = ga
        }
        if let lat {
            dictionary["lat"] = lat
        }
        if let dedupeKey {
            dictionary["dk"] = dedupeKey
        }

        return dictionary
    }
}
