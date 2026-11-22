import Foundation
import XCTest
@testable import EyeRestLogic

final class MedicineModelTests: XCTestCase {
    func testReminderNormalizesNameAndSortsTimes() throws {
        let reminder = try makeReminder(name: "  Vitamin D  ", times: [1_020, 480])
        XCTAssertEqual(reminder.name, "Vitamin D")
        XCTAssertEqual(reminder.times, [480, 1_020])
    }

    func testReminderRejectsInvalidFields() {
        XCTAssertThrowsError(try makeReminder(name: " "))
        XCTAssertThrowsError(try makeReminder(times: [60, 60]))
        XCTAssertThrowsError(try makeReminder(times: [1_440]))
        XCTAssertThrowsError(try makeReminder(repeatRule: .weekdays([])))
        XCTAssertThrowsError(try makeReminder(endDay: MedicineDay(year: 2026, month: 1, day: 1), startDay: MedicineDay(year: 2026, month: 1, day: 2)))
        XCTAssertThrowsError(try makeReminder(snoozeMinutes: 7))
    }

    func testMedicineDataToleratesMissingOptionalFieldsAndSkipsUnknownRecords() throws {
        let reminder = try makeReminder()
        let entry = try makeEntry(medicineID: reminder.id, action: .taken)
        let encoded = try JSONEncoder().encode(MedicineData(reminders: [reminder], log: [entry]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var reminders = try XCTUnwrap(object["reminders"] as? [[String: Any]])
        reminders.append(["id": UUID().uuidString, "name": "Bad", "times": [480], "repeatRule": ["kind": "future"], "startDay": ["year": 2026, "month": 1, "day": 1]])
        object["reminders"] = reminders
        var log = try XCTUnwrap(object["log"] as? [[String: Any]])
        var badLog = log[0]
        badLog["id"] = UUID().uuidString
        badLog["action"] = "future"
        log.append(badLog)
        object["log"] = log
        object.removeValue(forKey: "hasAcknowledgedNotice")
        object.removeValue(forKey: "hideNamesInNotifications")

        let decoded = try JSONDecoder().decode(MedicineData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.reminders, [reminder])
        XCTAssertEqual(decoded.log, [entry])
        XCTAssertFalse(decoded.hasAcknowledgedNotice)
        XCTAssertFalse(decoded.hideNamesInNotifications)
    }
}

final class MedicineScheduleTests: XCTestCase {
    func testNoneRepeatsOnlyOnInclusiveStartDay() throws {
        let calendar = testCalendar()
        let reminder = try makeReminder(times: [9 * 60], repeatRule: .none, startDay: MedicineDay(year: 2026, month: 3, day: 2))
        let values = MedicineSchedule.occurrences(
            of: reminder,
            from: testDate(2026, 3, 1, 0, 0, calendar: calendar),
            to: testDate(2026, 3, 3, 23, 59, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(values.map { calendar.component(.day, from: $0.scheduledAt) }, [2])
    }

    func testDailyUsesInclusiveStartAndEndWithSeveralTimes() throws {
        let calendar = testCalendar()
        let reminder = try makeReminder(
            times: [8 * 60, 20 * 60],
            repeatRule: .daily,
            startDay: MedicineDay(year: 2026, month: 3, day: 2),
            endDay: MedicineDay(year: 2026, month: 3, day: 3)
        )
        let values = MedicineSchedule.occurrences(
            of: reminder,
            from: testDate(2026, 3, 1, 0, 0, calendar: calendar),
            to: testDate(2026, 3, 4, 23, 59, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(values.count, 4)
        XCTAssertEqual(values.map { calendar.component(.day, from: $0.scheduledAt) }, [2, 2, 3, 3])
    }

    func testWeekdaysUseCalendarWeekdayValues() throws {
        let calendar = testCalendar()
        let reminder = try makeReminder(
            repeatRule: .weekdays([2, 4]),
            startDay: MedicineDay(year: 2026, month: 3, day: 1)
        )
        let values = MedicineSchedule.occurrences(
            of: reminder,
            from: testDate(2026, 3, 1, 0, 0, calendar: calendar),
            to: testDate(2026, 3, 7, 23, 59, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(values.map { calendar.component(.weekday, from: $0.scheduledAt) }, [2, 4])
    }

    func testSeveralRemindersAtSameTimeRemainDistinct() throws {
        let calendar = testCalendar()
        let first = try makeReminder(name: "First")
        let second = try makeReminder(name: "Second")
        let from = testDate(2026, 1, 2, 0, 0, calendar: calendar)
        let to = testDate(2026, 1, 2, 23, 59, calendar: calendar)
        let values = MedicineSchedule.occurrences(of: [first, second], from: from, to: to, calendar: calendar)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(Set(values.map(\.medicineID)), [first.id, second.id])
        XCTAssertEqual(values[0].scheduledAt, values[1].scheduledAt)
    }

    func testDSTGapAndOverlapEachProduceOneOccurrence() throws {
        let calendar = testCalendar("America/New_York")
        let spring = try makeReminder(times: [2 * 60 + 30], repeatRule: .none, startDay: MedicineDay(year: 2026, month: 3, day: 8))
        let springValues = MedicineSchedule.occurrences(
            of: spring,
            from: testDate(2026, 3, 8, 0, 0, calendar: calendar),
            to: testDate(2026, 3, 8, 23, 59, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(springValues.count, 1)
        XCTAssertEqual(calendar.component(.day, from: springValues[0].scheduledAt), 8)

        let fall = try makeReminder(times: [90], repeatRule: .none, startDay: MedicineDay(year: 2026, month: 11, day: 1))
        let fallValues = MedicineSchedule.occurrences(
            of: fall,
            from: testDate(2026, 11, 1, 0, 0, calendar: calendar),
            to: testDate(2026, 11, 1, 23, 59, calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(fallValues.count, 1)
        XCTAssertEqual(calendar.component(.hour, from: fallValues[0].scheduledAt), 1)
        XCTAssertEqual(calendar.component(.minute, from: fallValues[0].scheduledAt), 30)
    }

    func testTimeZoneChangeKeepsLocalWallClockTime() throws {
        let vietnam = testCalendar("Asia/Ho_Chi_Minh")
        let newYork = testCalendar("America/New_York")
        let reminder = try makeReminder(times: [9 * 60], repeatRule: .none, startDay: MedicineDay(year: 2026, month: 6, day: 1))
        let vietnamValue = try XCTUnwrap(MedicineSchedule.occurrences(
            of: reminder,
            from: testDate(2026, 6, 1, 0, 0, calendar: vietnam),
            to: testDate(2026, 6, 1, 23, 59, calendar: vietnam),
            calendar: vietnam
        ).first)
        let newYorkValue = try XCTUnwrap(MedicineSchedule.occurrences(
            of: reminder,
            from: testDate(2026, 6, 1, 0, 0, calendar: newYork),
            to: testDate(2026, 6, 1, 23, 59, calendar: newYork),
            calendar: newYork
        ).first)
        XCTAssertEqual(vietnam.component(.hour, from: vietnamValue.scheduledAt), 9)
        XCTAssertEqual(newYork.component(.hour, from: newYorkValue.scheduledAt), 9)
        XCTAssertNotEqual(vietnamValue.scheduledAt, newYorkValue.scheduledAt)
    }

    func testStatusFinalOutcomeWinsAndLatestFinalIsUsed() throws {
        let calendar = testCalendar()
        let occurrence = makeOccurrence(calendar: calendar)
        let taken = try makeEntry(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt, markedAt: occurrence.scheduledAt.addingTimeInterval(60), action: .taken)
        let snoozed = try makeEntry(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt, markedAt: occurrence.scheduledAt.addingTimeInterval(120), action: .snoozed, snoozeMinutes: 15)
        let skipped = try makeEntry(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt, markedAt: occurrence.scheduledAt.addingTimeInterval(180), action: .skipped)
        XCTAssertEqual(
            MedicineSchedule.status(for: occurrence, log: [taken, snoozed, skipped], now: occurrence.scheduledAt.addingTimeInterval(240), calendar: calendar),
            .skipped(markedAt: skipped.markedAt)
        )
    }

    func testStatusHandlesSnoozeExpiryAndDoesNotInferPastMisses() throws {
        let calendar = testCalendar()
        let occurrence = makeOccurrence(calendar: calendar)
        let snoozed = try makeEntry(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt, markedAt: occurrence.scheduledAt, action: .snoozed, snoozeMinutes: 5)
        XCTAssertEqual(
            MedicineSchedule.status(for: occurrence, log: [snoozed], now: occurrence.scheduledAt.addingTimeInterval(60), calendar: calendar),
            .snoozed(until: occurrence.scheduledAt.addingTimeInterval(300))
        )
        XCTAssertEqual(
            MedicineSchedule.status(for: occurrence, log: [snoozed], now: occurrence.scheduledAt.addingTimeInterval(600), calendar: calendar),
            .notRecorded
        )
        let tomorrow = testDate(2026, 1, 3, 12, 0, calendar: calendar)
        XCTAssertEqual(MedicineSchedule.status(for: occurrence, log: [], now: tomorrow, calendar: calendar), .noOutcome)
    }
}

final class MedicineStoreTests: XCTestCase {
    func testRoundTripAndDefaults() throws {
        let fixture = try makeStoreFixture()
        let reminder = try makeReminder()
        let entry = try makeEntry(medicineID: reminder.id, action: .taken)
        let expected = MedicineData(reminders: [reminder], log: [entry], hasAcknowledgedNotice: true, hideNamesInNotifications: true)
        try fixture.store.save(expected)
        XCTAssertEqual(fixture.store.load(), expected)
    }

    func testCorruptFileIsCopiedAndRecoveryStartsEmpty() throws {
        let fixture = try makeStoreFixture()
        try FileManager.default.createDirectory(at: fixture.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fixture.url)
        XCTAssertEqual(fixture.store.load(), MedicineData())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.url.appendingPathExtension("corrupt").path))
        XCTAssertNoThrow(try JSONDecoder().decode(MedicineData.self, from: Data(contentsOf: fixture.url)))
    }

    func testSavePrunesOldestLogEntries() throws {
        let fixture = try makeStoreFixture()
        let medicineID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = try (0...MedicineStore.maximumLogEntries).map { offset in
            try makeEntry(
                id: UUID(),
                medicineID: medicineID,
                scheduledAt: base,
                markedAt: base.addingTimeInterval(TimeInterval(offset)),
                action: .taken
            )
        }
        try fixture.store.save(MedicineData(log: entries))
        let loaded = fixture.store.load()
        XCTAssertEqual(loaded.log.count, MedicineStore.maximumLogEntries)
        XCTAssertEqual(loaded.log.first?.markedAt, base.addingTimeInterval(1))
        XCTAssertEqual(loaded.log.last?.markedAt, base.addingTimeInterval(TimeInterval(MedicineStore.maximumLogEntries)))
    }
}

private func makeReminder(
    name: String = "Medicine",
    times: [Int] = [8 * 60],
    repeatRule: MedicineRepeatRule = .daily,
    endDay: MedicineDay? = nil,
    startDay: MedicineDay = MedicineDay(year: 2026, month: 1, day: 2),
    snoozeMinutes: Int = 10
) throws -> MedicineReminder {
    try MedicineReminder(
        name: name,
        times: times,
        repeatRule: repeatRule,
        startDay: startDay,
        endDay: endDay,
        snoozeMinutes: snoozeMinutes
    )
}

private func makeEntry(
    id: UUID = UUID(),
    medicineID: UUID,
    scheduledAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
    markedAt: Date = Date(timeIntervalSince1970: 1_700_000_060),
    action: MedicineLogAction,
    snoozeMinutes: Int? = nil
) throws -> MedicineLogEntry {
    try MedicineLogEntry(
        id: id,
        medicineID: medicineID,
        nameSnapshot: "Medicine",
        scheduledAt: scheduledAt,
        markedAt: markedAt,
        action: action,
        snoozeMinutes: snoozeMinutes
    )
}

private func makeOccurrence(calendar: Calendar) -> MedicineOccurrence {
    MedicineOccurrence(
        medicineID: UUID(),
        name: "Medicine",
        scheduledAt: testDate(2026, 1, 2, 8, 0, calendar: calendar)
    )
}

private func makeStoreFixture() throws -> (store: MedicineStore, url: URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("medicine-v1.json")
    return (MedicineStore(fileURL: url), url)
}
