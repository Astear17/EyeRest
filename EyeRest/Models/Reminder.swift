import Foundation

enum ReminderKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case eyeRest, hydration, blinking, posture, movement
    var id: String { rawValue }
    var title: String { switch self { case .eyeRest: return String(localized: "Eye relaxation"); case .hydration: return String(localized: "Hydration"); case .blinking: return String(localized: "Blinking"); case .posture: return String(localized: "Posture"); case .movement: return String(localized: "Movement") } }
    var symbol: String { switch self { case .eyeRest: return "eye"; case .hydration: return "drop"; case .blinking: return "eye.trianglebadge.exclamationmark"; case .posture: return "figure.stand"; case .movement: return "figure.walk" } }
    var defaultMinutes: Int { switch self { case .eyeRest, .blinking: return 30; case .hydration, .posture: return 60; case .movement: return 90 } }
    var defaultMessage: String { switch self { case .eyeRest: return String(localized: "Time to rest your eyes. Look at something about 20 feet (6 m) away for 20 seconds."); case .hydration: return String(localized: "Take a moment to drink some water."); case .blinking: return String(localized: "Remember to blink naturally and relax your eyes."); case .posture: return String(localized: "Check your posture and relax your shoulders."); case .movement: return String(localized: "Take a short movement break.") } }

    var knownDefaultMessages: Set<String> {
        switch self {
        case .eyeRest:
            return ["Time to rest your eyes. Look into the distance for 30 seconds.", "Look into the distance for 30 seconds.", "Time to rest your eyes. Look at something about 20 feet (6 m) away for 20 seconds."]
        case .hydration:
            return ["Take a moment to drink some water."]
        case .blinking:
            return ["Remember to blink naturally and relax your eyes."]
        case .posture:
            return ["Check your posture and relax your shoulders."]
        case .movement:
            return ["Take a short movement break."]
        }
    }
}

enum NotificationPriority: String, CaseIterable, Codable, Identifiable {
    case timeSensitive, normal, quiet
    var id: String { rawValue }
    var title: String { switch self { case .timeSensitive: return String(localized: "Time Sensitive"); case .normal: return String(localized: "Normal"); case .quiet: return String(localized: "Quiet") } }
}

struct ReminderConfiguration: Codable, Identifiable, Equatable {
    let kind: ReminderKind
    var isEnabled: Bool
    var intervalMinutes: Int
    var customMessage: String?
    var nextFireDate: Date?
    var id: String { kind.rawValue }
    var message: String {
        get { customMessage ?? kind.defaultMessage }
        set { customMessage = Self.normalizedCustomMessage(newValue) }
    }

    init(kind: ReminderKind, isEnabled: Bool, intervalMinutes: Int, customMessage: String?, nextFireDate: Date?) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
        self.customMessage = Self.normalizedCustomMessage(customMessage)
        self.nextFireDate = nextFireDate
    }

    static func `default`(_ kind: ReminderKind, from now: Date = .now) -> Self {
        .init(kind: kind, isEnabled: true, intervalMinutes: kind.defaultMinutes, customMessage: nil, nextFireDate: Calendar.autoupdatingCurrent.date(byAdding: .minute, value: kind.defaultMinutes, to: now))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ReminderKind.self, forKey: .kind)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? kind.defaultMinutes
        nextFireDate = try container.decodeIfPresent(Date.self, forKey: .nextFireDate)
        let current = try container.decodeIfPresent(String.self, forKey: .customMessage)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self).decodeIfPresent(String.self, forKey: .message)
        let candidate = current ?? legacy
        if let candidate, kind.knownDefaultMessages.contains(candidate.trimmingCharacters(in: .whitespacesAndNewlines)) {
            customMessage = nil
        } else {
            customMessage = Self.normalizedCustomMessage(candidate)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(intervalMinutes, forKey: .intervalMinutes)
        try container.encodeIfPresent(Self.normalizedCustomMessage(customMessage), forKey: .customMessage)
        try container.encodeIfPresent(nextFireDate, forKey: .nextFireDate)
    }

    static func normalizedCustomMessage(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return String(value.prefix(200))
    }

    private enum CodingKeys: String, CodingKey { case kind, isEnabled, intervalMinutes, customMessage, nextFireDate }
    private enum LegacyCodingKeys: String, CodingKey { case message }
}

struct QuietHours: Codable, Equatable {
    var enabled = false
    var startMinutes = 22 * 60
    var endMinutes = 7 * 60

    init(enabled: Bool = false, startMinutes: Int = 22 * 60, endMinutes: Int = 7 * 60) {
        self.enabled = enabled
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        startMinutes = try container.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 22 * 60
        endMinutes = try container.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 7 * 60
    }
    func contains(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard enabled else { return false }
        guard startMinutes != endMinutes else { return false }
        let value = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return startMinutes < endMinutes ? value >= startMinutes && value < endMinutes : value >= startMinutes || value < endMinutes
    }
    func nextAllowedDate(_ date: Date, stagger: TimeInterval = 0, calendar: Calendar = .autoupdatingCurrent) -> Date {
        guard contains(date, calendar: calendar) else { return date }
        let value = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        var endDay = date
        if startMinutes > endMinutes, value >= startMinutes {
            endDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        guard let end = calendar.date(bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: endDay) else { return date }
        guard let staggered = calendar.date(byAdding: .second, value: Int(stagger), to: end) else { return end }
        return contains(staggered, calendar: calendar) ? end : staggered
    }
}

extension ReminderKind {
    var quietHoursStagger: TimeInterval {
        TimeInterval((Self.allCases.firstIndex(of: self) ?? 0) * 3 * 60)
    }
}

struct AppPreferences: Codable, Equatable {
    var reminders: [ReminderConfiguration]
    var quietHours = QuietHours()
    var priority: NotificationPriority = .timeSensitive
    var appearance: Appearance = .system
    var isPaused = false
    enum Appearance: String, CaseIterable, Codable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return String(localized: "System")
            case .light: return String(localized: "Light")
            case .dark: return String(localized: "Dark")
            }
        }
    }
    static func makeDefault(now: Date = .now) -> Self { .init(reminders: ReminderKind.allCases.map { .default($0, from: now) }) }

    init(reminders: [ReminderConfiguration], quietHours: QuietHours = QuietHours(), priority: NotificationPriority = .timeSensitive, appearance: Appearance = .system, isPaused: Bool = false) {
        self.reminders = reminders
        self.quietHours = quietHours
        self.priority = priority
        self.appearance = appearance
        self.isPaused = isPaused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decodeIfPresent([LossyReminder].self, forKey: .reminders)?.compactMap(\.value) ?? []
        var byKind: [ReminderKind: ReminderConfiguration] = [:]
        decoded.forEach { byKind[$0.kind] = $0 }
        reminders = ReminderKind.allCases.map { byKind[$0] ?? .default($0) }
        quietHours = try container.decodeIfPresent(QuietHours.self, forKey: .quietHours) ?? QuietHours()
        priority = try container.decodeIfPresent(NotificationPriority.self, forKey: .priority) ?? .timeSensitive
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .system
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
    }

    private struct LossyReminder: Decodable {
        let value: ReminderConfiguration?
        init(from decoder: Decoder) throws { value = try? ReminderConfiguration(from: decoder) }
    }
}
