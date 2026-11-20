import Foundation
import XCTest
@testable import EyeRestLogic

final class ActivityLogTests: XCTestCase {
    func testAppendUpdatesDailyTotalsAndPruneKeepsTotalsForever() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 20, 12, 0, calendar: calendar)
        let old = testDate(2025, 10, 1, 12, 0, calendar: calendar)
        var log = ActivityLog()
        log.append(ActivityEvent(kind: .eyeRest, completedAt: old, durationSeconds: 20, source: .guided, calendar: calendar))
        log.append(ActivityEvent(kind: .hydration, completedAt: now, durationSeconds: 0, source: .manual, calendar: calendar))
        log.append(ActivityEvent(kind: .eyeRest, completedAt: now, durationSeconds: 20, source: .guided, calendar: calendar))

        XCTAssertEqual(log.total(for: "2026-11-20")?.completionCount, 2)
        XCTAssertEqual(log.total(for: "2026-11-20")?.countsByKind[.eyeRest], 1)
        XCTAssertEqual(log.total(for: "2026-11-20")?.seconds, 20)

        log.pruneEvents(asOf: now, calendar: calendar)
        XCTAssertEqual(log.events.count, 2)
        XCTAssertEqual(log.total(for: "2025-10-01")?.seconds, 20)
    }

    func testStreakStaysAliveThroughTodayAndBestStreakCrossesDST() {
        let calendar = testCalendar("America/Los_Angeles")
        var log = ActivityLog()
        for day in [6, 7, 8] {
            log.append(ActivityEvent(
                kind: .posture,
                completedAt: testDate(2026, 3, day, 12, 0, calendar: calendar),
                source: .manual,
                calendar: calendar
            ))
        }
        let dayAfterDST = testDate(2026, 3, 9, 18, 0, calendar: calendar)
        XCTAssertEqual(log.currentStreak(asOf: dayAfterDST, calendar: calendar), 3)
        XCTAssertEqual(log.bestStreak(calendar: calendar), 3)
    }

    func testDayKeyRemainsStableAcrossTimeZoneChange() throws {
        let vietnam = testCalendar("Asia/Ho_Chi_Minh")
        let losAngeles = testCalendar("America/Los_Angeles")
        let completedAt = testDate(2026, 11, 20, 0, 30, calendar: vietnam)
        let original = ActivityEvent(kind: .movement, completedAt: completedAt, source: .manual, calendar: vietnam)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded.dayKey, "2026-11-20")
        XCTAssertNotEqual(ActivityEvent.dayKey(for: completedAt, calendar: losAngeles), decoded.dayKey)
    }

    func testLegacyMigrationIsIdempotentAndKeepsOldKey() throws {
        let defaults = makeDefaults()
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("activity-v1.json")
        let completion = Completion(kind: .posture, completedAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
        defaults.set(try JSONEncoder().encode([completion]), forKey: ActivityStore.legacyCompletionsKey)
        let store = ActivityStore(defaults: defaults, fileURL: fileURL)

        let first = store.load()
        let second = store.load()

        XCTAssertEqual(first.events.count, 1)
        XCTAssertEqual(second.events.count, 1)
        XCTAssertEqual(second.events.first?.source, .legacy)
        XCTAssertNotNil(defaults.data(forKey: ActivityStore.legacyCompletionsKey))
    }

    func testCorruptActivityFileIsBackedUpAndLegacyFallbackStillMigrates() throws {
        let defaults = makeDefaults()
        let directory = makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("activity-v1.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: fileURL)
        let completion = Completion(kind: .blinking, completedAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
        defaults.set(try JSONEncoder().encode([completion]), forKey: ActivityStore.legacyCompletionsKey)

        let loaded = ActivityStore(defaults: defaults, fileURL: fileURL).load()

        XCTAssertEqual(loaded.events.count, 1)
        XCTAssertEqual(try Data(contentsOf: fileURL.appendingPathExtension("corrupt")), corrupt)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "EyeRestActivityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EyeRestTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
