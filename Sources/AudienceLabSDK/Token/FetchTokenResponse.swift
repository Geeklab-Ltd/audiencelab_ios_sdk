import Foundation

struct FetchTokenResponse {
    let token: String?
    let message: String?
    let whitelistedProperties: [String: Any]?
    let lifecycle: LifecycleResponse?

    init(payload: [String: Any]) {
        token = Self.normalizedString(payload["token"])
        message = Self.normalizedString(payload["message"])
        whitelistedProperties = payload["wp"] as? [String: Any]
        lifecycle = LifecycleResponse(payload: payload)
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

struct LifecycleResponse: Equatable {
    let installId: String?
    let decisionCode: String?
    let refreshAfter: Date?

    init?(payload: [String: Any]) {
        let installId = Self.normalizedString(payload["x7"])
        let decisionCode = Self.normalizedString(payload["x9"])
        let refreshAfter = Self.parseRefreshAfter(payload["xm"])

        guard installId != nil || decisionCode != nil || refreshAfter != nil else {
            return nil
        }

        self.installId = installId
        self.decisionCode = decisionCode
        self.refreshAfter = refreshAfter
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func parseRefreshAfter(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }

        guard let string = normalizedString(value) else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        return ISO8601DateFormatter().date(from: string)
    }
}
