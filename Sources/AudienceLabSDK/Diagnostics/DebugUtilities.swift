import Foundation

#if DEBUG
enum DebugUtilities {
    static func mask(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else { return nil }

        switch normalized.count {
        case 0:
            return nil
        case 1...4:
            return String(repeating: "*", count: normalized.count)
        case 5...10:
            return String(normalized.prefix(2)) + "..." + String(normalized.suffix(2))
        default:
            return String(normalized.prefix(4)) + "..." + String(normalized.suffix(4))
        }
    }

    static func jsonString(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return string
    }

    static func apiKeyPreview(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else { return nil }
        if normalized.count <= 6 {
            return "***"
        }
        return String(normalized.prefix(3)) + "***" + String(normalized.suffix(3))
    }
}
#endif
