import Foundation

struct PlannedNotification: Equatable {
    let id: String
    let kind: ReminderKind
    let fireDate: Date
    let title: String
    let body: String
}

struct PlannedMedicineNotification: Equatable {
    let id: String
    let medicineID: UUID
    let scheduledAt: Date
    let title: String
    let body: String
    let snoozeMinutes: Int
}

struct CombinedNotificationPlan: Equatable {
    let wellness: [PlannedNotification]
    let medicine: [PlannedMedicineNotification]

    var count: Int { wellness.count + medicine.count }
}

struct NotificationReconciliationDiff: Equatable {
    let staleWellnessIDs: [String]
    let staleMedicineIDs: [String]

    var allStaleIDs: [String] { staleWellnessIDs + staleMedicineIDs }
}

enum NotificationPlanner {
    static let maxPending = 64
    static let snoozeReserve = 6
    static let medicineLimit = 28
    static let wellnessMinimum = 30
    static let guaranteedPerKind = 3

    static func plan(preferences: AppPreferences, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [PlannedNotification] {
        wellnessPlan(preferences: preferences, now: now, budget: maxPending - snoozeReserve, calendar: calendar)
    }

    static func combinedPlan(
        preferences: AppPreferences,
        medicineData: MedicineData,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CombinedNotificationPlan {
        let regularBudget = maxPending - snoozeReserve
        let medicine = medicinePlan(data: medicineData, now: now, calendar: calendar)
        let wellnessBudget = max(wellnessMinimum, regularBudget - medicine.count)
        return CombinedNotificationPlan(
            wellness: wellnessPlan(preferences: preferences, now: now, budget: wellnessBudget, calendar: calendar),
            medicine: medicine
        )
    }

    static func medicineIdentifier(medicineID: UUID, scheduledAt: Date) -> String {
        "eyerest.med.\(medicineID.uuidString).\(MedicineDoseIdentity(medicineID: medicineID, scheduledAt: scheduledAt).scheduledEpochSeconds)"
    }

    static func medicineSnoozeIdentifier(medicineID: UUID, scheduledAt: Date) -> String {
        "eyerest.snooze.med.\(medicineID.uuidString).\(MedicineDoseIdentity(medicineID: medicineID, scheduledAt: scheduledAt).scheduledEpochSeconds)"
    }

    static func medicineSnoozeDate(now: Date, minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(minutes * 60))
    }

    static func reconciliationDiff(
        pendingIDs: [String],
        plan: CombinedNotificationPlan
    ) -> NotificationReconciliationDiff {
        let wellnessIDs = Set(plan.wellness.map(\.id))
        let medicineIDs = Set(plan.medicine.map(\.id))
        return NotificationReconciliationDiff(
            staleWellnessIDs: pendingIDs.filter { isWellnessIdentifier($0) && !wellnessIDs.contains($0) }.sorted(),
            staleMedicineIDs: pendingIDs.filter { isMedicineIdentifier($0) && !medicineIDs.contains($0) }.sorted()
        )
    }

    private static func wellnessPlan(
        preferences: AppPreferences,
        now: Date,
        budget: Int,
        calendar: Calendar
    ) -> [PlannedNotification] {
        if preferences.pausedUntil == .distantFuture { return [] }
        let enabled = ReminderKind.allCases.compactMap { kind in
            preferences.reminders.first { $0.kind == kind && $0.isEnabled }
        }
        guard !enabled.isEmpty else { return [] }

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

    private static func medicinePlan(
        data: MedicineData,
        now: Date,
        calendar: Calendar
    ) -> [PlannedMedicineNotification] {
        guard let horizon = calendar.date(byAdding: .year, value: 1, to: now) else { return [] }
        let candidates = MedicineSchedule.occurrences(of: data.reminders, from: now, to: horizon, calendar: calendar)
            .filter { occurrence in
                switch MedicineSchedule.status(for: occurrence, log: data.log, now: now, calendar: calendar) {
                case .taken, .skipped, .snoozed:
                    return false
                case .upcoming, .notRecorded, .noOutcome:
                    return true
                }
            }
        let grouped = Dictionary(grouping: candidates, by: \.medicineID)
        let orderedIDs = grouped.keys.sorted { lhs, rhs in
            let left = grouped[lhs]?.first?.scheduledAt ?? .distantFuture
            let right = grouped[rhs]?.first?.scheduledAt ?? .distantFuture
            if left != right { return left < right }
            return lhs.uuidString < rhs.uuidString
        }
        var selected: [MedicineOccurrence] = []
        var selectedIDs = Set<MedicineDoseIdentity>()

        for index in 0..<2 {
            for id in orderedIDs where selected.count < medicineLimit {
                guard let occurrence = grouped[id]?[safe: index] else { continue }
                selected.append(occurrence)
                selectedIDs.insert(occurrence.id)
            }
        }
        for occurrence in candidates where selected.count < medicineLimit && !selectedIDs.contains(occurrence.id) {
            selected.append(occurrence)
            selectedIDs.insert(occurrence.id)
        }

        let reminderByID = Dictionary(uniqueKeysWithValues: data.reminders.map { ($0.id, $0) })
        return selected.sorted {
            if $0.scheduledAt != $1.scheduledAt { return $0.scheduledAt < $1.scheduledAt }
            return $0.medicineID.uuidString < $1.medicineID.uuidString
        }.compactMap { occurrence in
            guard let reminder = reminderByID[occurrence.medicineID] else { return nil }
            return PlannedMedicineNotification(
                id: medicineIdentifier(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt),
                medicineID: occurrence.medicineID,
                scheduledAt: occurrence.scheduledAt,
                title: data.hideNamesInNotifications ? String(localized: "Medicine reminder") : occurrence.name,
                body: String(localized: "Time for your medicine"),
                snoozeMinutes: reminder.snoozeMinutes
            )
        }
    }

    private static func firstFireDate(for reminder: ReminderConfiguration, preferences: AppPreferences, now: Date, calendar: Calendar) -> Date {
        let proposed: Date
        if let stored = reminder.nextFireDate, stored > now {
            proposed = stored
        } else {
            proposed = calendar.date(byAdding: .minute, value: reminder.intervalMinutes, to: now) ?? now
        }
        return ScheduleRules.adjustedDate(proposed, kind: reminder.kind, preferences: preferences, calendar: calendar) ?? proposed
    }

    private static func nextFireDate(after fire: Date, reminder: ReminderConfiguration, preferences: AppPreferences, calendar: Calendar) -> Date {
        let proposed = calendar.date(byAdding: .minute, value: reminder.intervalMinutes, to: fire) ?? fire
        return ScheduleRules.adjustedDate(proposed, kind: reminder.kind, preferences: preferences, calendar: calendar) ?? proposed
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

    private static func isWellnessIdentifier(_ id: String) -> Bool {
        ReminderKind.allCases.contains { id.hasPrefix("eyerest.\($0.rawValue).") }
    }

    private static func isMedicineIdentifier(_ id: String) -> Bool {
        id.hasPrefix("eyerest.med.")
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
