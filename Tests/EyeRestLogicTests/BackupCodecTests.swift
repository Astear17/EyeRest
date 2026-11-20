import Foundation
import XCTest
@testable import EyeRestLogic

final class BackupCodecTests: XCTestCase {
    func testRoundTripReproducesSettingsAndActivityWithoutNextFireDates() throws {
        var preferences = AppPreferences.makeDefault(now: Date(timeIntervalSince1970: 1_700_000_000))
        preferences.activeDays = [2, 3, 4, 5, 6]
        preferences.snoozeMinutes = 10
        preferences.quietHours = QuietHours(enabled: true, startMinutes: 18 * 60, endMinutes: 9 * 60)
        preferences.hapticsEnabled = false
        var log = ActivityLog()
        log.append(ActivityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .eyeRest,
            activityID: "eye-rest",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 20,
            source: .guided
        ))

        let data = try BackupCodec.encode(
            preferences: preferences,
            activityLog: log,
            appVersion: "1.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let decoded = try BackupCodec.decode(data).backup

        XCTAssertEqual(decoded.settings, BackupSettings(preferences: preferences))
        XCTAssertEqual(decoded.activity.log, log)
        XCTAssertTrue(decoded.settings.preferences().reminders.allSatisfy { $0.nextFireDate == nil })
        XCTAssertEqual(decoded.payloadSHA256.count, 64)
    }

    func testNewerVersionIsRejectedBeforeImport() throws {
        let data = try validData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 2
        let changed = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BackupCodec.decode(changed)) { error in
            XCTAssertEqual(error as? BackupCodecError, .newerSchema(2))
        }
    }

    func testChecksumMismatchTruncatedAndGarbageAreRejected() throws {
        let data = try validData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["appVersion"] = "changed"
        XCTAssertThrowsError(try BackupCodec.decode(try JSONSerialization.data(withJSONObject: object))) { error in
            XCTAssertEqual(error as? BackupCodecError, .checksumMismatch)
        }
        XCTAssertThrowsError(try BackupCodec.decode(data.prefix(data.count / 2)))
        XCTAssertThrowsError(try BackupCodec.decode(Data("garbage".utf8)))
    }

    func testDuplicateEventsMergeByUUID() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = ActivityEvent(id: id, kind: .hydration, completedAt: .now, source: .manual)
        let second = ActivityEvent(id: id, kind: .hydration, completedAt: .now, source: .manual)
        var current = ActivityLog()
        current.append(first)
        var imported = ActivityLog()
        imported.append(second)

        let merged = BackupCodec.mergedActivity(current: current, imported: imported)

        XCTAssertEqual(merged.events.count, 1)
        XCTAssertEqual(merged.dailyTotals.first?.completionCount, 1)
    }

    func testExtremeValuesAreRejected() throws {
        var preferences = AppPreferences.makeDefault()
        preferences.reminders[0].intervalMinutes = 10_000
        let data = try BackupCodec.encode(preferences: preferences, activityLog: ActivityLog(), appVersion: "1.0")
        XCTAssertThrowsError(try BackupCodec.decode(data)) { error in
            XCTAssertEqual(error as? BackupCodecError, .invalidValue("intervalMinutes"))
        }
    }

    private func validData() throws -> Data {
        try BackupCodec.encode(
            preferences: AppPreferences.makeDefault(now: Date(timeIntervalSince1970: 1_700_000_000)),
            activityLog: ActivityLog(),
            appVersion: "1.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
    }
}
