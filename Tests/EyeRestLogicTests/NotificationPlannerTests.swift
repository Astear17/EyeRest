import XCTest
@testable import EyeRestLogic

final class NotificationPlannerTests: XCTestCase {
    func testPausedReturnsEmpty() {
        var preferences = AppPreferences.makeDefault()
        preferences.isPaused = true
        XCTAssertTrue(NotificationPlanner.plan(preferences: preferences, now: Date()).isEmpty)
    }

    func testBudgetGuaranteesAndDefaultHorizonFairness() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 10, 0, calendar: calendar)
        let preferences = configuredPreferences(now: now, calendar: calendar)
        let planned = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(planned.count, NotificationPlanner.maxPending - NotificationPlanner.snoozeReserve)
        for kind in ReminderKind.allCases {
            XCTAssertGreaterThanOrEqual(planned.filter { $0.kind == kind }.count, NotificationPlanner.guaranteedPerKind)
        }
        let lastDates = ReminderKind.allCases.compactMap { kind in planned.last { $0.kind == kind }?.fireDate }
        XCTAssertEqual(lastDates.count, ReminderKind.allCases.count)
        XCTAssertLessThanOrEqual(lastDates.max()!.timeIntervalSince(lastDates.min()!), 90 * 60)
    }

    func testLongIntervalIsNotStarvedByShortInterval() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 10, 0, calendar: calendar)
        var preferences = configuredPreferences(now: now, calendar: calendar)
        for index in preferences.reminders.indices {
            preferences.reminders[index].isEnabled = preferences.reminders[index].kind == .eyeRest || preferences.reminders[index].kind == .hydration
            if preferences.reminders[index].kind == .eyeRest { preferences.reminders[index].intervalMinutes = 5 }
            if preferences.reminders[index].kind == .hydration { preferences.reminders[index].intervalMinutes = 360 }
            preferences.reminders[index].nextFireDate = calendar.date(byAdding: .minute, value: preferences.reminders[index].intervalMinutes, to: now)
        }
        let planned = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        XCTAssertGreaterThanOrEqual(planned.filter { $0.kind == .hydration }.count, 3)
        XCTAssertLessThanOrEqual(planned.count, 58)
    }

    func testIdentifiersAreStableForIdenticalInput() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 10, 0, calendar: calendar)
        let preferences = configuredPreferences(now: now, calendar: calendar)
        let first = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        let second = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testQuietHoursNeverContainPlannedDatesAndMorningIsStaggered() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 21, 0, calendar: calendar)
        var preferences = configuredPreferences(now: now, calendar: calendar)
        preferences.quietHours = QuietHours(enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60)
        let inside = testDate(2026, 11, 20, 23, 0, calendar: calendar)
        for index in preferences.reminders.indices { preferences.reminders[index].nextFireDate = inside }
        let planned = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        XCTAssertFalse(planned.contains { preferences.quietHours.contains($0.fireDate, calendar: calendar) })
        let firstByKind = ReminderKind.allCases.compactMap { kind in planned.first { $0.kind == kind } }
        XCTAssertEqual(firstByKind.map { calendar.component(.hour, from: $0.fireDate) }, [7, 7, 7, 7, 7])
        XCTAssertEqual(firstByKind.map { calendar.component(.minute, from: $0.fireDate) }, [0, 3, 6, 9, 12])
    }

    private func configuredPreferences(now: Date, calendar: Calendar) -> AppPreferences {
        var preferences = AppPreferences.makeDefault(now: now)
        for index in preferences.reminders.indices {
            preferences.reminders[index].nextFireDate = calendar.date(byAdding: .minute, value: preferences.reminders[index].intervalMinutes, to: now)
        }
        return preferences
    }
}
