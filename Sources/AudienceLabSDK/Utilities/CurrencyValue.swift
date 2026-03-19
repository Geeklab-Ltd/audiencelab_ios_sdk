import Foundation

enum CurrencyValue {
    private static let scale = 8
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func decimal(from value: Double) -> Decimal {
        if let parsed = Decimal(string: String(value), locale: locale) {
            return normalize(parsed)
        }
        return normalize(Decimal(value))
    }

    static func decimal(fromStored object: Any?) -> Decimal {
        switch object {
        case let value as String:
            if let parsed = Decimal(string: value, locale: locale) {
                return normalize(parsed)
            }
            return .zero
        case let value as NSNumber:
            return decimal(from: value.doubleValue)
        default:
            return .zero
        }
    }

    static func normalize(_ value: Double) -> Double {
        double(from: decimal(from: value))
    }

    static func normalize(_ decimal: Decimal) -> Decimal {
        var source = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, scale, .plain)
        return rounded
    }

    static func double(from decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: normalize(decimal)).doubleValue
    }

    static func storageString(from decimal: Decimal) -> String {
        NSDecimalNumber(decimal: normalize(decimal)).stringValue
    }

    static func decimalNumber(from value: Double) -> NSDecimalNumber {
        NSDecimalNumber(decimal: decimal(from: value))
    }
}
