import Foundation
import UserNotifications

enum ReminderKind: String, CaseIterable, Codable, Identifiable {
    case eyeRest, hydration, blinking, posture, movement
    var id: String { rawValue }
    var title: String { switch self { case .eyeRest: return "Eye relaxation"; case .hydration: return "Hydration"; case .blinking: return "Blinking"; case .posture: return "Posture"; case .movement: return "Movement" } }
    var symbol: String { switch self { case .eyeRest: return "eye"; case .hydration: return "drop"; case .blinking: return "eye.trianglebadge.exclamationmark"; case .posture: return "figure.stand"; case .movement: return "figure.walk" } }
    var defaultMinutes: Int { switch self { case .eyeRest, .blinking: return 30; case .hydration, .posture: return 60; case .movement: return 90 } }
    var defaultMessage: String { switch self { case .eyeRest: return "Time to rest your eyes. Look into the distance for 30 seconds."; case .hydration: return "Take a moment to drink some water."; case .blinking: return "Remember to blink naturally and relax your eyes."; case .posture: return "Check your posture and relax your shoulders."; case .movement: return "Take a short movement break." } }
}

enum NotificationPriority: String, CaseIterable, Codable, Identifiable {
    case timeSensitive, normal, quiet
    var id: String { rawValue }
    var title: String { switch self { case .timeSensitive: return "Time Sensitive"; case .normal: return "Normal"; case .quiet: return "Quiet" } }
    var interruptionLevel: UNNotificationInterruptionLevel { self == .timeSensitive ? .timeSensitive : .active }
}

struct ReminderConfiguration: Codable, Identifiable, Equatable {
    let kind: ReminderKind
    var isEnabled: Bool
    var intervalMinutes: Int
    var message: String
    var nextFireDate: Date?
    var id: String { kind.rawValue }
    static func `default`(_ kind: ReminderKind, from now: Date = .now) -> Self {
        .init(kind: kind, isEnabled: true, intervalMinutes: kind.defaultMinutes, message: kind.defaultMessage, nextFireDate: Calendar.current.date(byAdding: .minute, value: kind.defaultMinutes, to: now))
    }
}

struct QuietHours: Codable, Equatable {
    var enabled = false
    var startMinutes = 22 * 60
    var endMinutes = 7 * 60
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let value = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return startMinutes <= endMinutes ? (startMinutes...endMinutes).contains(value) : value >= startMinutes || value <= endMinutes
    }
}

struct AppPreferences: Codable, Equatable {
    var reminders: [ReminderConfiguration]
    var quietHours = QuietHours()
    var priority: NotificationPriority = .timeSensitive
    var appearance: Appearance = .system
    var isPaused = false
    enum Appearance: String, CaseIterable, Codable, Identifiable { case system, light, dark; var id: String { rawValue }; var title: String { rawValue.capitalized } }
    static func makeDefault(now: Date = .now) -> Self { .init(reminders: ReminderKind.allCases.map { .default($0, from: now) }) }
}
