import Foundation
import CryptoKit
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

        let medicine = try MedicineReminder(
            name: "Vitamin D",
            times: [8 * 60],
            repeatRule: .daily,
            startDay: MedicineDay(year: 2026, month: 1, day: 1)
        )
        let medicineData = MedicineData(reminders: [medicine], hasAcknowledgedNotice: true, hideNamesInNotifications: true)
        let data = try BackupCodec.encode(
            preferences: preferences,
            activityLog: log,
            medicineData: medicineData,
            appVersion: "1.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let decoded = try BackupCodec.decode(data).backup

        XCTAssertEqual(decoded.settings, BackupSettings(preferences: preferences))
        XCTAssertEqual(decoded.activity.log, log)
        XCTAssertEqual(decoded.medicine?.data, medicineData)
        XCTAssertTrue(decoded.settings.preferences().reminders.allSatisfy { $0.nextFireDate == nil })
        XCTAssertEqual(decoded.payloadSHA256.count, 64)
    }

    func testVersionOneBackupImportsWithoutMedicineReplacement() throws {
        let preferences = AppPreferences.makeDefault(now: Date(timeIntervalSince1970: 1_700_000_000))
        let unsigned = LegacyUnsignedBackup(
            format: BackupCodec.format,
            schemaVersion: 1,
            appVersion: "1.0",
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100),
            settings: BackupSettings(preferences: preferences),
            activity: BackupActivity(log: ActivityLog())
        )
        let encoder = canonicalEncoder()
        let checksum = SHA256.hash(data: try encoder.encode(unsigned)).map { String(format: "%02x", $0) }.joined()
        let data = try encoder.encode(LegacyBackup(
            format: unsigned.format,
            schemaVersion: unsigned.schemaVersion,
            appVersion: unsigned.appVersion,
            exportedAt: unsigned.exportedAt,
            settings: unsigned.settings,
            activity: unsigned.activity,
            payloadSHA256: checksum
        ))
        let preview = try BackupCodec.decode(data)
        XCTAssertNil(preview.backup.medicine)
        let current = MedicineData(hasAcknowledgedNotice: true, hideNamesInNotifications: true)
        XCTAssertEqual(BackupCodec.mergedMedicine(current: current, imported: preview.backup.medicine), current)
    }

    func testMedicineImportReplacesRemindersAndMergesLogByUUID() throws {
        let currentReminder = try MedicineReminder(name: "Old", times: [480], repeatRule: .daily, startDay: MedicineDay(year: 2026, month: 1, day: 1))
        let importedReminder = try MedicineReminder(name: "New", times: [540], repeatRule: .daily, startDay: MedicineDay(year: 2026, month: 1, day: 1))
        let sharedID = UUID()
        let currentEntry = try MedicineLogEntry(id: sharedID, medicineID: currentReminder.id, nameSnapshot: "Old", scheduledAt: .now, action: .taken)
        let duplicate = try MedicineLogEntry(id: sharedID, medicineID: importedReminder.id, nameSnapshot: "New", scheduledAt: .now, action: .skipped)
        let additional = try MedicineLogEntry(medicineID: importedReminder.id, nameSnapshot: "New", scheduledAt: .now, action: .taken)
        let merged = BackupCodec.mergedMedicine(
            current: MedicineData(reminders: [currentReminder], log: [currentEntry]),
            imported: BackupMedicine(data: MedicineData(reminders: [importedReminder], log: [duplicate, additional], hideNamesInNotifications: true))
        )
        XCTAssertEqual(merged.reminders, [importedReminder])
        XCTAssertEqual(merged.log.count, 2)
        XCTAssertEqual(merged.log.first(where: { $0.id == sharedID }), currentEntry)
        XCTAssertTrue(merged.hideNamesInNotifications)
    }

    func testNewerVersionIsRejectedBeforeImport() throws {
        let data = try validData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 3
        let changed = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BackupCodec.decode(changed)) { error in
            XCTAssertEqual(error as? BackupCodecError, .newerSchema(3))
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

private struct LegacyUnsignedBackup: Codable {
    let format: String
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let settings: BackupSettings
    let activity: BackupActivity
}

private struct LegacyBackup: Codable {
    let format: String
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let settings: BackupSettings
    let activity: BackupActivity
    let payloadSHA256: String
}

private func canonicalEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .millisecondsSince1970
    return encoder
}
