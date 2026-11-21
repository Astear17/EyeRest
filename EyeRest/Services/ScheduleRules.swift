import Foundation

enum ScheduleRules {
    static func adjustedDate(
        _ candidate: Date,
        kind: ReminderKind,
        preferences: AppPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        guard preferences.reminders.contains(where: { $0.kind == kind && $0.isEnabled }) else { return nil }
        if preferences.pausedUntil == .distantFuture { return nil }
        var result = candidate
        for _ in 0..<8 {
            let previous = result
            if let pausedUntil = preferences.pausedUntil, pausedUntil > result { result = pausedUntil }
            if !preferences.activeDays.contains(calendar.component(.weekday, from: result)) {
                result = nextActiveDay(after: result, activeDays: preferences.activeDays, calendar: calendar)
            }
            result = preferences.quietHours.nextAllowedDate(result, stagger: kind.quietHoursStagger, calendar: calendar)
            if result == previous { return result }
        }
        return result
    }

    private static func nextActiveDay(after date: Date, activeDays: Set<Int>, calendar: Calendar) -> Date {
        var cursor = date
        for _ in 0..<7 {
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
            if activeDays.contains(calendar.component(.weekday, from: cursor)) { return cursor }
        }
        return cursor
    }
}
