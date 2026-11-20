import Foundation
import XCTest
@testable import EyeRestLogic

final class PersistenceTests: XCTestCase {
    func testVersionOnePreferencesPreserveSettingsAndMigrateMessages() throws {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let reminders = ReminderKind.allCases.map { kind in
            LegacyReminder(
                kind: kind,
                isEnabled: kind != .movement,
                intervalMinutes: kind.defaultMinutes + 5,
                message: kind == .hydration ? "My bottle reminder" : legacyDefault(for: kind),
                nextFireDate: now.addingTimeInterval(TimeInterval(kind.defaultMinutes * 60))
            )
        }
        let legacy = LegacyPreferences(
            reminders: reminders,
            quietHours: QuietHours(enabled: true, startMinutes: 21 * 60, endMinutes: 6 * 60),
            priority: .quiet,
            appearance: .dark,
            isPaused: true
        )
        defaults.set(try JSONEncoder().encode(legacy), forKey: "EyeRest.preferences.v1")
        let loaded = PersistenceService(defaults: defaults).loadPreferences()
        XCTAssertEqual(loaded.quietHours, legacy.quietHours)
        XCTAssertEqual(loaded.priority, .quiet)
        XCTAssertEqual(loaded.appearance, .dark)
        XCTAssertTrue(loaded.isPaused)
        XCTAssertEqual(loaded.reminders.first { $0.kind == .hydration }?.customMessage, "My bottle reminder")
        XCTAssertNil(loaded.reminders.first { $0.kind == .eyeRest }?.customMessage)
        XCTAssertNil(loaded.reminders.first { $0.kind == .movement }?.customMessage)
        XCTAssertFalse(loaded.reminders.first { $0.kind == .movement }!.isEnabled)
    }

    func testUnknownReminderIsDroppedMissingKindIsAddedAndMissingFieldDefaults() throws {
        let defaults = makeDefaults()
        var preferences = AppPreferences.makeDefault()
        preferences.reminders[0].customMessage = "Custom eye text"
        let encoded = try JSONEncoder().encode(preferences)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "priority")
        var reminders = try XCTUnwrap(object["reminders"] as? [[String: Any]])
        reminders.removeAll { ($0["kind"] as? String) == ReminderKind.movement.rawValue }
        reminders.append(["kind": "futureReminder", "isEnabled": true, "intervalMinutes": 10])
        object["reminders"] = reminders
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "EyeRest.preferences.v1")
        let loaded = PersistenceService(defaults: defaults).loadPreferences()
        XCTAssertEqual(loaded.reminders.map(\.kind), ReminderKind.allCases)
        XCTAssertEqual(loaded.priority, .timeSensitive)
        XCTAssertEqual(loaded.reminders.first { $0.kind == .eyeRest }?.customMessage, "Custom eye text")
        XCTAssertEqual(loaded.reminders.first { $0.kind == .movement }?.intervalMinutes, ReminderKind.movement.defaultMinutes)
    }

    func testCorruptPreferencesReturnDefaultsAndCreateBackup() {
        let defaults = makeDefaults()
        let corrupt = Data("not-json".utf8)
        defaults.set(corrupt, forKey: "EyeRest.preferences.v1")
        let loaded = PersistenceService(defaults: defaults).loadPreferences()
        XCTAssertEqual(loaded.reminders.map(\.kind), ReminderKind.allCases)
        XCTAssertEqual(defaults.data(forKey: "EyeRest.preferences.v1.corrupt"), corrupt)
    }

    func testCompletionsDecodeLossilyAndTotallyCorruptDataIsBackedUp() throws {
        let defaults = makeDefaults()
        let completion = Completion(kind: .posture, completedAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let validObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(completion))
        defaults.set(try JSONSerialization.data(withJSONObject: [validObject, ["bad": true]]), forKey: "EyeRest.completions.v1")
        let service = PersistenceService(defaults: defaults)
        let loaded = service.loadCompletions()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.kind, .posture)

        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: "EyeRest.completions.v1")
        XCTAssertTrue(service.loadCompletions().isEmpty)
        XCTAssertEqual(defaults.data(forKey: "EyeRest.completions.v1.corrupt"), corrupt)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "EyeRestLogicTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func legacyDefault(for kind: ReminderKind) -> String {
        switch kind {
        case .eyeRest: return "Time to rest your eyes. Look into the distance for 30 seconds."
        case .hydration: return "Take a moment to drink some water."
        case .blinking: return "Remember to blink naturally and relax your eyes."
        case .posture: return "Check your posture and relax your shoulders."
        case .movement: return "Take a short movement break."
        }
    }

    private struct LegacyReminder: Encodable {
        let kind: ReminderKind
        let isEnabled: Bool
        let intervalMinutes: Int
        let message: String
        let nextFireDate: Date?
    }

    private struct LegacyPreferences: Encodable {
        let reminders: [LegacyReminder]
        let quietHours: QuietHours
        let priority: NotificationPriority
        let appearance: AppPreferences.Appearance
        let isPaused: Bool
    }
}
