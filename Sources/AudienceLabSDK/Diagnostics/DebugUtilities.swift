import Foundation

#if DEBUG
enum DebugUtilities {
    private static let redactedKeys: Set<String> = [
        "aid",
        "asid",
        "creativeToken",
        "ga",
        "ifv",
        "token",
        "x1",
        "x7"
    ]

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

    static func sanitizedJSONString(_ value: Any) -> String {
        if let string = value as? String {
            guard let data = string.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                return "<non-JSON response omitted>"
            }
            return jsonString(redact(json))
        }

        return jsonString(redact(value))
    }

    static func apiKeyPreview(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else { return nil }
        if normalized.count <= 6 {
            return "***"
        }
        return String(normalized.prefix(3)) + "***" + String(normalized.suffix(3))
    }

    private static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, element in
                let (key, nestedValue) = element
                result[key] = redactedKeys.contains(key) ? "<redacted>" : redact(nestedValue)
            }
        }

        if let array = value as? [Any] {
            return array.map(redact)
        }

        return value
    }
}
#endif
