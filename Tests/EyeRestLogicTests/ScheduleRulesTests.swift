import XCTest
@testable import EyeRestLogic

final class ScheduleRulesTests: XCTestCase {
    func testPauseActiveDaysAndQuietHoursApplyInPrecedenceOrder() {
        let calendar = testCalendar()
        let friday = testDate(2026, 11, 20, 17, 0, calendar: calendar)
        var preferences = AppPreferences.makeDefault(now: friday)
        preferences.activeDays = [2, 3, 4, 5, 6]
        preferences.quietHours = QuietHours(enabled: true, startMinutes: 18 * 60, endMinutes: 9 * 60)
        preferences.pausedUntil = testDate(2026, 11, 21, 10, 0, calendar: calendar)

        let result = ScheduleRules.adjustedDate(friday, kind: .eyeRest, preferences: preferences, calendar: calendar)

        XCTAssertEqual(calendar.component(.weekday, from: result!), 2)
        XCTAssertEqual(calendar.component(.hour, from: result!), 9)
    }

    func testPauseAcrossMidnightAndDSTAreCalendarSafe() {
        let calendar = testCalendar("America/Los_Angeles")
        let beforeDST = testDate(2026, 3, 7, 23, 30, calendar: calendar)
        var preferences = AppPreferences.makeDefault(now: beforeDST)
        preferences.pausedUntil = testDate(2026, 3, 8, 4, 0, calendar: calendar)
        XCTAssertEqual(ScheduleRules.adjustedDate(beforeDST, kind: .posture, preferences: preferences, calendar: calendar), preferences.pausedUntil)
    }

    func testNextActiveDayPreservesWallClockTimeWithoutQuietHours() {
        let calendar = testCalendar()
        let saturday = testDate(2026, 11, 21, 14, 35, calendar: calendar)
        var preferences = AppPreferences.makeDefault(now: saturday)
        preferences.activeDays = [2, 3, 4, 5, 6]

        let result = ScheduleRules.adjustedDate(saturday, kind: .hydration, preferences: preferences, calendar: calendar)

        XCTAssertEqual(calendar.component(.weekday, from: result!), 2)
        XCTAssertEqual(calendar.component(.hour, from: result!), 14)
        XCTAssertEqual(calendar.component(.minute, from: result!), 35)
    }

    func testIndefinitePauseAndDisabledKindReturnNil() {
        var preferences = AppPreferences.makeDefault()
        preferences.pausedUntil = .distantFuture
        XCTAssertNil(ScheduleRules.adjustedDate(.now, kind: .movement, preferences: preferences))
        preferences.pausedUntil = nil
        preferences.reminders[0].isEnabled = false
        XCTAssertNil(ScheduleRules.adjustedDate(.now, kind: .eyeRest, preferences: preferences))
    }

    func testPlannerRespectsWorkWeekAndBudgetWithStableIdentifiers() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 17, 0, calendar: calendar)
        var preferences = AppPreferences.makeDefault(now: now)
        preferences.activeDays = [2, 3, 4, 5, 6]
        preferences.quietHours = QuietHours(enabled: true, startMinutes: 18 * 60, endMinutes: 9 * 60)
        let first = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        let second = NotificationPlanner.plan(preferences: preferences, now: now, calendar: calendar)
        XCTAssertLessThanOrEqual(first.count, 58)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertTrue(first.allSatisfy {
            preferences.activeDays.contains(calendar.component(.weekday, from: $0.fireDate)) &&
            !preferences.quietHours.contains($0.fireDate, calendar: calendar)
        })
    }
}
