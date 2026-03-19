import Foundation

enum DateUtils {
    private static let eventFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static func nowTimestamp() -> String {
        nowTimestamp(at: Date())
    }

    static func nowTimestamp(at date: Date) -> String {
        eventFormatter.string(from: date)
    }

    static func todayDayString() -> String {
        todayDayString(on: Date())
    }

    static func todayDayString(on date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func parseDay(_ value: String) -> Date? {
        dayFormatter.date(from: value)
    }

    static func utcOffsetString() -> String {
        let offset = TimeZone.current.secondsFromGMT()
        let sign = offset >= 0 ? "+" : "-"
        let absolute = abs(offset)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    static func utcOffsetHours() -> Double {
        Double(TimeZone.current.secondsFromGMT()) / 3600.0
    }

    static func timezoneIdentifier() -> String {
        TimeZone.current.identifier
    }
}
