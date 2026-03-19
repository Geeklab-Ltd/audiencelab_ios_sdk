import Foundation

final class RetentionTracker {
    private let keyFirstLogin = "AudienceLabSDK_FirstLogin"
    private let keyLastLogin = "AudienceLabSDK_LastLogin"
    private let keyRetentionDay = "AudienceLabSDK_RetentionDay"
    private let keyBackfillDay = "AudienceLabSDK_BackfillDay"
    private let keyLastSentMetricDate = "AudienceLabSDK_LastSentMetricDate"
    private let clock: Clock
    private let calendar: Calendar

    init(clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.clock = clock
        self.calendar = calendar
    }

    func prepareForLaunch() {
        let today = DateUtils.todayDayString(on: clock.now)
        let firstLogin = PersistenceManager.shared.string(for: keyFirstLogin)

        if firstLogin == nil {
            PersistenceManager.shared.set(today, for: keyFirstLogin)
            PersistenceManager.shared.set(today, for: keyLastLogin)
            PersistenceManager.shared.set("0", for: keyRetentionDay)
            if PersistenceManager.shared.string(for: keyBackfillDay) == nil {
                PersistenceManager.shared.set("0", for: keyBackfillDay)
            }
            return
        }

        let firstDate = DateUtils.parseDay(firstLogin ?? today) ?? clock.now
        let todayDate = DateUtils.parseDay(today) ?? clock.now
        let retentionDay = calendar.dateComponents([.day], from: firstDate, to: todayDate).day ?? 0
        PersistenceManager.shared.set(String(retentionDay), for: keyRetentionDay)
    }

    func updateRetentionIfNeeded() -> [String: Any]? {
        let today = DateUtils.todayDayString(on: clock.now)
        if PersistenceManager.shared.string(for: keyLastSentMetricDate) == today {
            return nil
        }

        let firstLogin = PersistenceManager.shared.string(for: keyFirstLogin)
        if firstLogin == nil {
            PersistenceManager.shared.set(today, for: keyFirstLogin)
            PersistenceManager.shared.set(today, for: keyLastLogin)
            PersistenceManager.shared.set("0", for: keyRetentionDay)
            PersistenceManager.shared.set("0", for: keyBackfillDay)
            PersistenceManager.shared.set(today, for: keyLastSentMetricDate)
            return [
                "retention_day": 0,
                "backfill_day": 0
            ]
        }

        let lastLogin = PersistenceManager.shared.string(for: keyLastLogin) ?? today
        let firstDate = DateUtils.parseDay(firstLogin ?? today) ?? clock.now
        let todayDate = DateUtils.parseDay(today) ?? clock.now
        var backfillDay = 0

        if lastLogin != today, let lastDate = DateUtils.parseDay(lastLogin) {
            backfillDay = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            PersistenceManager.shared.set(today, for: keyLastLogin)
        }

        let retentionDay = calendar.dateComponents([.day], from: firstDate, to: todayDate).day ?? 0
        PersistenceManager.shared.set(String(retentionDay), for: keyRetentionDay)
        PersistenceManager.shared.set(String(backfillDay), for: keyBackfillDay)
        PersistenceManager.shared.set(today, for: keyLastSentMetricDate)

        return [
            "retention_day": retentionDay,
            "backfill_day": backfillDay
        ]
    }

    func currentRetentionDay() -> Int? {
        guard let raw = PersistenceManager.shared.string(for: keyRetentionDay), let parsed = Int(raw) else {
            return nil
        }
        return parsed
    }
}
