import Foundation

struct PlannedNotification: Equatable {
    let id: String
    let kind: ReminderKind
    let fireDate: Date
    let title: String
    let body: String
}

enum NotificationPlanner {
    static let maxPending = 64
    static let snoozeReserve = 6
    static let guaranteedPerKind = 3

    static func plan(preferences: AppPreferences, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [PlannedNotification] {
        guard preferences.pausedUntil.map({ $0 <= now }) ?? true else { return [] }
        let enabled = ReminderKind.allCases.compactMap { kind in
            preferences.reminders.first { $0.kind == kind && $0.isEnabled }
        }
        guard !enabled.isEmpty else { return [] }

        let budget = maxPending - snoozeReserve
        var planned: [PlannedNotification] = []
        var nextDates: [ReminderKind: Date] = [:]

        for reminder in enabled {
            var fire = firstFireDate(for: reminder, preferences: preferences, now: now, calendar: calendar)
            for _ in 0..<guaranteedPerKind where planned.count < budget {
                planned.append(notification(for: reminder, fireDate: fire))
                fire = nextFireDate(after: fire, reminder: reminder, preferences: preferences, calendar: calendar)
            }
            nextDates[reminder.kind] = fire
        }

        while planned.count < budget, let reminder = earliestReminder(in: enabled, nextDates: nextDates) {
            guard let fire = nextDates[reminder.kind] else { break }
            planned.append(notification(for: reminder, fireDate: fire))
            nextDates[reminder.kind] = nextFireDate(after: fire, reminder: reminder, preferences: preferences, calendar: calendar)
        }

        return planned.sorted { lhs, rhs in
            if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
            return kindIndex(lhs.kind) < kindIndex(rhs.kind)
        }
    }

    private static func firstFireDate(for reminder: ReminderConfiguration, preferences: AppPreferences, now: Date, calendar: Calendar) -> Date {
        let proposed: Date
        if let stored = reminder.nextFireDate, stored > now {
            proposed = stored
        } else {
            proposed = calendar.date(byAdding: .minute, value: reminder.intervalMinutes, to: now) ?? now
        }
        return preferences.quietHours.nextAllowedDate(proposed, stagger: reminder.kind.quietHoursStagger, calendar: calendar)
    }

    private static func nextFireDate(after fire: Date, reminder: ReminderConfiguration, preferences: AppPreferences, calendar: Calendar) -> Date {
        let proposed = calendar.date(byAdding: .minute, value: reminder.intervalMinutes, to: fire) ?? fire
        return preferences.quietHours.nextAllowedDate(proposed, stagger: reminder.kind.quietHoursStagger, calendar: calendar)
    }

    private static func notification(for reminder: ReminderConfiguration, fireDate: Date) -> PlannedNotification {
        PlannedNotification(
            id: "eyerest.\(reminder.kind.rawValue).\(Int(fireDate.timeIntervalSince1970))",
            kind: reminder.kind,
            fireDate: fireDate,
            title: reminder.kind.title,
            body: reminder.message
        )
    }

    private static func earliestReminder(in reminders: [ReminderConfiguration], nextDates: [ReminderKind: Date]) -> ReminderConfiguration? {
        reminders.min { lhs, rhs in
            guard let left = nextDates[lhs.kind], let right = nextDates[rhs.kind] else { return false }
            if left != right { return left < right }
            return kindIndex(lhs.kind) < kindIndex(rhs.kind)
        }
    }

    private static func kindIndex(_ kind: ReminderKind) -> Int {
        ReminderKind.allCases.firstIndex(of: kind) ?? 0
    }
}
