import Foundation
import XCTest
@testable import EyeRestLogic

final class MedicineNotificationPlannerTests: XCTestCase {
    func testCombinedBudgetGivesMedicinePriorityAndKeepsWellnessMinimum() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 1, 1, 7, 0, calendar: calendar)
        let reminders = try (0..<10).map { index in
            try plannerReminder(name: "Medicine \(index)", minute: 8 * 60 + index, startDay: MedicineDay(now, calendar: calendar))
        }
        let plan = NotificationPlanner.combinedPlan(
            preferences: plannerPreferences(now: now, calendar: calendar),
            medicineData: MedicineData(reminders: reminders),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(plan.medicine.count, NotificationPlanner.medicineLimit)
        XCTAssertEqual(plan.wellness.count, NotificationPlanner.wellnessMinimum)
        XCTAssertEqual(plan.count, NotificationPlanner.maxPending - NotificationPlanner.snoozeReserve)
        for reminder in reminders {
            XCTAssertGreaterThanOrEqual(plan.medicine.filter { $0.medicineID == reminder.id }.count, 2)
        }
    }

    func testUnusedMedicineCapacityReturnsToWellness() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 1, 1, 7, 0, calendar: calendar)
        let reminder = try plannerReminder(
            repeatRule: .none,
            startDay: MedicineDay(now, calendar: calendar)
        )
        let plan = NotificationPlanner.combinedPlan(
            preferences: plannerPreferences(now: now, calendar: calendar),
            medicineData: MedicineData(reminders: [reminder]),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(plan.medicine.count, 1)
        XCTAssertEqual(plan.wellness.count, 57)
        XCTAssertEqual(plan.count, 58)
    }

    func testWellnessPauseDoesNotPauseMedicine() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 1, 1, 7, 0, calendar: calendar)
        var preferences = plannerPreferences(now: now, calendar: calendar)
        preferences.pausedUntil = .distantFuture
        let reminder = try plannerReminder(startDay: MedicineDay(now, calendar: calendar))
        let plan = NotificationPlanner.combinedPlan(
            preferences: preferences,
            medicineData: MedicineData(reminders: [reminder]),
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(plan.wellness.isEmpty)
        XCTAssertFalse(plan.medicine.isEmpty)
    }

    func testFinalAndActiveSnoozeOutcomesAreNotReplanned() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 1, 1, 7, 0, calendar: calendar)
        let takenReminder = try plannerReminder(name: "Taken", minute: 8 * 60, repeatRule: .none, startDay: MedicineDay(now, calendar: calendar))
        let snoozedReminder = try plannerReminder(name: "Snoozed", minute: 9 * 60, repeatRule: .none, startDay: MedicineDay(now, calendar: calendar))
        let takenDate = testDate(2026, 1, 1, 8, 0, calendar: calendar)
        let snoozedDate = testDate(2026, 1, 1, 9, 0, calendar: calendar)
        let taken = try MedicineLogEntry(medicineID: takenReminder.id, nameSnapshot: takenReminder.name, scheduledAt: takenDate, markedAt: now, action: .taken)
        let snoozed = try MedicineLogEntry(medicineID: snoozedReminder.id, nameSnapshot: snoozedReminder.name, scheduledAt: snoozedDate, markedAt: now, action: .snoozed, snoozeMinutes: 15)
        let plan = NotificationPlanner.combinedPlan(
            preferences: plannerPreferences(now: now, calendar: calendar),
            medicineData: MedicineData(reminders: [takenReminder, snoozedReminder], log: [taken, snoozed]),
            now: now,
            calendar: calendar
        )
        XCTAssertFalse(plan.medicine.contains { $0.medicineID == takenReminder.id })
        XCTAssertFalse(plan.medicine.contains { $0.medicineID == snoozedReminder.id })
    }

    func testMedicineIdentifiersAndSnoozeDateAreStable() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let date = Date(timeIntervalSince1970: 1_800_000_000.4)
        XCTAssertEqual(NotificationPlanner.medicineIdentifier(medicineID: id, scheduledAt: date), "eyerest.med.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE.1800000000")
        XCTAssertEqual(NotificationPlanner.medicineSnoozeIdentifier(medicineID: id, scheduledAt: date), "eyerest.snooze.med.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE.1800000000")
        XCTAssertEqual(NotificationPlanner.medicineSnoozeDate(now: date, minutes: 10), date.addingTimeInterval(600))
    }

    func testReconciliationDiffNeverDeletesPlannedOtherKindOrSnoozes() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 1, 1, 7, 0, calendar: calendar)
        let reminder = try plannerReminder(repeatRule: .none, startDay: MedicineDay(now, calendar: calendar))
        let plan = NotificationPlanner.combinedPlan(
            preferences: plannerPreferences(now: now, calendar: calendar),
            medicineData: MedicineData(reminders: [reminder]),
            now: now,
            calendar: calendar
        )
        let keptWellness = try XCTUnwrap(plan.wellness.first?.id)
        let keptMedicine = try XCTUnwrap(plan.medicine.first?.id)
        let wellnessSnooze = "eyerest.snooze.eyeRest"
        let medicineSnooze = NotificationPlanner.medicineSnoozeIdentifier(medicineID: reminder.id, scheduledAt: plan.medicine[0].scheduledAt)
        let staleWellness = "eyerest.eyeRest.1"
        let staleMedicine = "eyerest.med.\(UUID()).1"
        let diff = NotificationPlanner.reconciliationDiff(
            pendingIDs: [keptWellness, keptMedicine, wellnessSnooze, medicineSnooze, staleWellness, staleMedicine, "unmanaged.request"],
            plan: plan
        )
        XCTAssertEqual(diff.staleWellnessIDs, [staleWellness])
        XCTAssertEqual(diff.staleMedicineIDs, [staleMedicine])
        XCTAssertFalse(diff.allStaleIDs.contains(wellnessSnooze))
        XCTAssertFalse(diff.allStaleIDs.contains(medicineSnooze))
        XCTAssertFalse(diff.allStaleIDs.contains(keptWellness))
        XCTAssertFalse(diff.allStaleIDs.contains(keptMedicine))
    }
}

private func plannerReminder(
    name: String = "Medicine",
    minute: Int = 8 * 60,
    repeatRule: MedicineRepeatRule = .daily,
    startDay: MedicineDay
) throws -> MedicineReminder {
    try MedicineReminder(name: name, times: [minute], repeatRule: repeatRule, startDay: startDay)
}

private func plannerPreferences(now: Date, calendar: Calendar) -> AppPreferences {
    var preferences = AppPreferences.makeDefault(now: now)
    for index in preferences.reminders.indices {
        preferences.reminders[index].nextFireDate = calendar.date(byAdding: .minute, value: preferences.reminders[index].intervalMinutes, to: now)
    }
    return preferences
}
