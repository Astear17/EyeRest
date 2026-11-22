import Foundation

struct MedicineOccurrence: Equatable, Identifiable {
    let medicineID: UUID
    let name: String
    let scheduledAt: Date
    var id: MedicineDoseIdentity { MedicineDoseIdentity(medicineID: medicineID, scheduledAt: scheduledAt) }
}

enum MedicineDoseStatus: Equatable {
    case taken(markedAt: Date)
    case skipped(markedAt: Date)
    case snoozed(until: Date)
    case upcoming
    case notRecorded
    case noOutcome
}

enum MedicineSchedule {
    static func occurrences(
        of reminder: MedicineReminder,
        from: Date,
        to: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [MedicineOccurrence] {
        guard reminder.isEnabled, from <= to else { return [] }
        let firstDay = MedicineDay(from, calendar: calendar)
        let lastDay = MedicineDay(to, calendar: calendar)
        var day = max(firstDay, reminder.startDay)
        let endDay = min(lastDay, reminder.endDay ?? lastDay)
        guard day <= endDay else { return [] }

        var result: [MedicineOccurrence] = []
        while day <= endDay {
            if applies(reminder.repeatRule, on: day, startDay: reminder.startDay, calendar: calendar) {
                for minute in reminder.times {
                    if let date = date(on: day, minute: minute, calendar: calendar), date >= from, date <= to {
                        result.append(MedicineOccurrence(medicineID: reminder.id, name: reminder.name, scheduledAt: date))
                    }
                }
            }
            guard let next = addingOneDay(to: day, calendar: calendar), next > day else { break }
            day = next
        }
        return result.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    static func occurrences(
        of reminders: [MedicineReminder],
        from: Date,
        to: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [MedicineOccurrence] {
        reminders.flatMap { occurrences(of: $0, from: from, to: to, calendar: calendar) }
            .sorted {
                if $0.scheduledAt == $1.scheduledAt { return $0.medicineID.uuidString < $1.medicineID.uuidString }
                return $0.scheduledAt < $1.scheduledAt
            }
    }

    static func status(
        for occurrence: MedicineOccurrence,
        log: [MedicineLogEntry],
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> MedicineDoseStatus {
        let identity = occurrence.id
        let matching = log.filter { $0.doseIdentity == identity }
        if let final = matching.filter({ $0.action == .taken || $0.action == .skipped }).max(by: { $0.markedAt < $1.markedAt }) {
            return final.action == .taken ? .taken(markedAt: final.markedAt) : .skipped(markedAt: final.markedAt)
        }
        if let snooze = matching.filter({ $0.action == .snoozed }).max(by: { $0.markedAt < $1.markedAt }),
           let minutes = snooze.snoozeMinutes {
            let until = snooze.markedAt.addingTimeInterval(TimeInterval(minutes * 60))
            if until > now { return .snoozed(until: until) }
        }
        if occurrence.scheduledAt > now { return .upcoming }
        if calendar.isDate(occurrence.scheduledAt, inSameDayAs: now) { return .notRecorded }
        return .noOutcome
    }

    private static func applies(
        _ rule: MedicineRepeatRule,
        on day: MedicineDay,
        startDay: MedicineDay,
        calendar: Calendar
    ) -> Bool {
        switch rule {
        case .none:
            return day == startDay
        case .daily:
            return true
        case let .weekdays(days):
            guard let anchor = noon(on: day, calendar: calendar) else { return false }
            return days.contains(calendar.component(.weekday, from: anchor))
        }
    }

    private static func date(on day: MedicineDay, minute: Int, calendar: Calendar) -> Date? {
        guard let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: day.year,
            month: day.month,
            day: day.day,
            hour: 0,
            minute: 0
        )), let searchStart = calendar.date(byAdding: .second, value: -1, to: start) else { return nil }
        let components = DateComponents(hour: minute / 60, minute: minute % 60)
        guard let match = calendar.nextDate(
            after: searchStart,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ), MedicineDay(match, calendar: calendar) == day else { return nil }
        return match
    }

    private static func noon(on day: MedicineDay, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: day.year,
            month: day.month,
            day: day.day,
            hour: 12
        ))
    }

    private static func addingOneDay(to day: MedicineDay, calendar: Calendar) -> MedicineDay? {
        guard let anchor = noon(on: day, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: 1, to: anchor) else { return nil }
        return MedicineDay(next, calendar: calendar)
    }
}
