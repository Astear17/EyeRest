import XCTest
@testable import EyeRestLogic

final class BreakActivityTests: XCTestCase {
    func testActivityDefinitionsHaveExpectedDurationsAndSteps() {
        XCTAssertEqual(BreakActivity.all.count, 4)
        XCTAssertEqual(BreakActivity.eyeRest.duration, 20)
        XCTAssertEqual(BreakActivity.eyeRelaxation.duration, 60)
        XCTAssertEqual(BreakActivity.postureCheck.duration, 30)
        XCTAssertEqual(BreakActivity.movement.duration, 120)
        XCTAssertEqual(BreakActivity.movement.stepDurations, [10, 30, 30, 40, 10])

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: BreakActivity.eyeRelaxation.duration, stepDurations: BreakActivity.eyeRelaxation.stepDurations)
        session.start(at: start)
        XCTAssertEqual(session.currentStepIndex(at: start.addingTimeInterval(19.9)), 0)
        XCTAssertEqual(session.currentStepIndex(at: start.addingTimeInterval(20)), 1)
        XCTAssertEqual(session.currentStepIndex(at: start.addingTimeInterval(40)), 2)
    }

    func testGuidedReminderKindsMapToTheirDefaultActivities() {
        XCTAssertEqual(BreakActivity.defaultActivity(for: .eyeRest)?.id, BreakActivity.eyeRest.id)
        XCTAssertEqual(BreakActivity.defaultActivity(for: .posture)?.id, BreakActivity.postureCheck.id)
        XCTAssertEqual(BreakActivity.defaultActivity(for: .movement)?.id, BreakActivity.movement.id)
        XCTAssertNil(BreakActivity.defaultActivity(for: .hydration))
        XCTAssertNil(BreakActivity.defaultActivity(for: .blinking))
    }

    func testCompletedGuidedSessionRecordsOneCompleteActivityEvent() {
        let activity = BreakActivity.postureCheck
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: activity.duration, stepDurations: activity.stepDurations)
        var log = ActivityLog()
        session.start(at: start)

        for offset in [30.0, 31.0] where session.update(at: start.addingTimeInterval(offset)) {
            log.append(ActivityEvent(
                kind: activity.reminderKind,
                activityID: activity.id,
                completedAt: start.addingTimeInterval(offset),
                durationSeconds: Int(activity.duration),
                source: .guided
            ))
        }

        XCTAssertEqual(log.events.count, 1)
        XCTAssertEqual(log.events.first?.activityID, activity.id)
        XCTAssertEqual(log.events.first?.durationSeconds, 30)
        XCTAssertEqual(log.events.first?.source, .guided)
    }

    func testEndingEarlyDoesNotRecordAnActivityEvent() {
        let activity = BreakActivity.movement
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var session = BreakSession(duration: activity.duration, stepDurations: activity.stepDurations)
        var log = ActivityLog()
        session.start(at: start)
        session.cancel()

        if session.update(at: start.addingTimeInterval(activity.duration)) {
            log.append(ActivityEvent(
                kind: activity.reminderKind,
                activityID: activity.id,
                durationSeconds: Int(activity.duration),
                source: .guided
            ))
        }

        XCTAssertTrue(log.events.isEmpty)
    }
}
