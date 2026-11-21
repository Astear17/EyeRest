import XCTest
@testable import EyeRestLogic

final class BreakSessionTests: XCTestCase {
    func testPauseResumePreservesRemainingTimeAndStep() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: 60, stepDurations: [20, 20, 20])
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(25))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(100)), 35)
        XCTAssertEqual(session.currentStepIndex(at: start.addingTimeInterval(100)), 1)
        session.resume(at: start.addingTimeInterval(100))
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(110)), 25)
    }

    func testCompletionReportsExactlyOnce() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: 20)
        session.start(at: start)
        XCTAssertFalse(session.update(at: start.addingTimeInterval(19.9)))
        XCTAssertTrue(session.update(at: start.addingTimeInterval(20)))
        XCTAssertFalse(session.update(at: start.addingTimeInterval(21)))
        XCTAssertEqual(session.state, .completed)
    }

    func testCancelAndClockEdges() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: 20)
        session.start(at: start)
        XCTAssertEqual(session.progress(at: start.addingTimeInterval(-5)), 0)
        session.cancel()
        XCTAssertEqual(session.state, .cancelled)
        XCTAssertFalse(session.update(at: start.addingTimeInterval(30)))
    }
}
