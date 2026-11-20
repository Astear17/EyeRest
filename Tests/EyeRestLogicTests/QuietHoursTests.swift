import XCTest
@testable import EyeRestLogic

final class QuietHoursTests: XCTestCase {
    func testOvernightWindowMovesBothSidesToMorningEnd() {
        let calendar = testCalendar()
        let quiet = QuietHours(enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60)
        let late = quiet.nextAllowedDate(testDate(2026, 11, 20, 23, 30, calendar: calendar), calendar: calendar)
        let early = quiet.nextAllowedDate(testDate(2026, 11, 21, 3, 0, calendar: calendar), calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: late), 21)
        XCTAssertEqual(calendar.component(.hour, from: late), 7)
        XCTAssertEqual(calendar.component(.hour, from: early), 7)
    }

    func testSameDayWindowAndEndBoundary() {
        let calendar = testCalendar()
        let quiet = QuietHours(enabled: true, startMinutes: 13 * 60, endMinutes: 15 * 60)
        let inside = quiet.nextAllowedDate(testDate(2026, 11, 20, 14, 0, calendar: calendar), calendar: calendar)
        let boundary = testDate(2026, 11, 20, 15, 0, calendar: calendar)
        XCTAssertEqual(inside, boundary)
        XCTAssertEqual(quiet.nextAllowedDate(boundary, calendar: calendar), boundary)
    }

    func testEqualEndpointsDisableQuietWindow() {
        let calendar = testCalendar()
        let quiet = QuietHours(enabled: true, startMinutes: 7 * 60, endMinutes: 7 * 60)
        let input = testDate(2026, 11, 20, 7, 0, calendar: calendar)
        XCTAssertEqual(quiet.nextAllowedDate(input, calendar: calendar), input)
    }

    func testStaggerAppliesOnlyWhenResultRemainsAllowed() {
        let calendar = testCalendar()
        let quiet = QuietHours(enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60)
        let input = testDate(2026, 11, 20, 23, 30, calendar: calendar)
        let staggered = quiet.nextAllowedDate(input, stagger: 12 * 60, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: staggered), 7)
        XCTAssertEqual(calendar.component(.minute, from: staggered), 12)
        let reentering = quiet.nextAllowedDate(input, stagger: 16 * 60, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: reentering), 7)
        XCTAssertEqual(calendar.component(.minute, from: reentering), 0)
    }

    func testDSTTransitionUsesCalendarEndTime() {
        let calendar = testCalendar("America/Los_Angeles")
        let quiet = QuietHours(enabled: true, startMinutes: 22 * 60, endMinutes: 7 * 60)
        let input = testDate(2026, 3, 8, 3, 30, calendar: calendar)
        let result = quiet.nextAllowedDate(input, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: result), 8)
        XCTAssertEqual(calendar.component(.hour, from: result), 7)
        XCTAssertEqual(calendar.component(.minute, from: result), 0)
    }
}
