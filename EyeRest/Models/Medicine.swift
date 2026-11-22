import Foundation

struct MedicineDay: Codable, Hashable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    static func < (lhs: MedicineDay, rhs: MedicineDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum MedicineRepeatRule: Equatable, Codable {
    case none
    case daily
    case weekdays(Set<Int>)

    private enum Kind: String, Codable { case none, daily, weekdays }
    private enum CodingKeys: String, CodingKey { case kind, weekdays }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .none:
            self = .none
        case .daily:
            self = .daily
        case .weekdays:
            let days = Set(try container.decode([Int].self, forKey: .weekdays))
            guard !days.isEmpty, days.allSatisfy({ (1...7).contains($0) }) else {
                throw DecodingError.dataCorruptedError(forKey: .weekdays, in: container, debugDescription: "Weekdays must contain Calendar weekday values 1 through 7")
            }
            self = .weekdays(days)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case let .weekdays(days):
            try container.encode(Kind.weekdays, forKey: .kind)
            try container.encode(days.sorted(), forKey: .weekdays)
        }
    }
}

enum MedicineValidationError: Error, Equatable {
    case invalidName
    case invalidTimes
    case invalidWeekdays
    case invalidDateRange
    case invalidSnooze
}

struct MedicineReminder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var times: [Int]
    var repeatRule: MedicineRepeatRule
    var startDay: MedicineDay
    var endDay: MedicineDay?
    var isEnabled: Bool
    var snoozeMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        times: [Int],
        repeatRule: MedicineRepeatRule,
        startDay: MedicineDay,
        endDay: MedicineDay? = nil,
        isEnabled: Bool = true,
        snoozeMinutes: Int = 10
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(trimmedName.count) else { throw MedicineValidationError.invalidName }
        let normalizedTimes = Array(Set(times)).sorted()
        guard normalizedTimes.count == times.count,
              (1...6).contains(normalizedTimes.count),
              normalizedTimes.allSatisfy({ (0..<1_440).contains($0) }) else {
            throw MedicineValidationError.invalidTimes
        }
        if case let .weekdays(days) = repeatRule,
           days.isEmpty || !days.allSatisfy({ (1...7).contains($0) }) {
            throw MedicineValidationError.invalidWeekdays
        }
        if let endDay, endDay < startDay { throw MedicineValidationError.invalidDateRange }
        guard [5, 10, 15].contains(snoozeMinutes) else { throw MedicineValidationError.invalidSnooze }

        self.id = id
        self.name = trimmedName
        self.times = normalizedTimes
        self.repeatRule = repeatRule
        self.startDay = startDay
        self.endDay = endDay
        self.isEnabled = isEnabled
        self.snoozeMinutes = snoozeMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, times, repeatRule, startDay, endDay, isEnabled, snoozeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: container.decode(String.self, forKey: .name),
            times: container.decode([Int].self, forKey: .times),
            repeatRule: container.decode(MedicineRepeatRule.self, forKey: .repeatRule),
            startDay: container.decode(MedicineDay.self, forKey: .startDay),
            endDay: container.decodeIfPresent(MedicineDay.self, forKey: .endDay),
            isEnabled: container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            snoozeMinutes: container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 10
        )
    }
}

enum MedicineLogAction: String, Codable, CaseIterable {
    case taken
    case skipped
    case snoozed
}

struct MedicineDoseIdentity: Hashable, Codable {
    let medicineID: UUID
    let scheduledEpochSeconds: Int64

    init(medicineID: UUID, scheduledAt: Date) {
        self.medicineID = medicineID
        scheduledEpochSeconds = Int64(scheduledAt.timeIntervalSince1970.rounded())
    }
}

struct MedicineLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let medicineID: UUID
    let nameSnapshot: String
    let scheduledAt: Date
    let markedAt: Date
    let action: MedicineLogAction
    let snoozeMinutes: Int?

    init(
        id: UUID = UUID(),
        medicineID: UUID,
        nameSnapshot: String,
        scheduledAt: Date,
        markedAt: Date = .now,
        action: MedicineLogAction,
        snoozeMinutes: Int? = nil
    ) throws {
        let trimmedName = nameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw MedicineValidationError.invalidName }
        if action == .snoozed {
            guard let snoozeMinutes, [5, 10, 15].contains(snoozeMinutes) else {
                throw MedicineValidationError.invalidSnooze
            }
        } else if snoozeMinutes != nil {
            throw MedicineValidationError.invalidSnooze
        }
        self.id = id
        self.medicineID = medicineID
        self.nameSnapshot = trimmedName
        self.scheduledAt = scheduledAt
        self.markedAt = markedAt
        self.action = action
        self.snoozeMinutes = snoozeMinutes
    }

    var doseIdentity: MedicineDoseIdentity {
        MedicineDoseIdentity(medicineID: medicineID, scheduledAt: scheduledAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, medicineID, nameSnapshot, scheduledAt, markedAt, action, snoozeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            medicineID: container.decode(UUID.self, forKey: .medicineID),
            nameSnapshot: container.decode(String.self, forKey: .nameSnapshot),
            scheduledAt: container.decode(Date.self, forKey: .scheduledAt),
            markedAt: container.decode(Date.self, forKey: .markedAt),
            action: container.decode(MedicineLogAction.self, forKey: .action),
            snoozeMinutes: container.decodeIfPresent(Int.self, forKey: .snoozeMinutes)
        )
    }
}

struct MedicineData: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var reminders: [MedicineReminder]
    var log: [MedicineLogEntry]
    var hasAcknowledgedNotice: Bool
    var hideNamesInNotifications: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        reminders: [MedicineReminder] = [],
        log: [MedicineLogEntry] = [],
        hasAcknowledgedNotice: Bool = false,
        hideNamesInNotifications: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.reminders = reminders
        self.log = log
        self.hasAcknowledgedNotice = hasAcknowledgedNotice
        self.hideNamesInNotifications = hideNamesInNotifications
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, reminders, log, hasAcknowledgedNotice, hideNamesInNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        reminders = (try container.decodeIfPresent([LossyMedicineValue<MedicineReminder>].self, forKey: .reminders) ?? []).compactMap(\.value)
        log = (try container.decodeIfPresent([LossyMedicineValue<MedicineLogEntry>].self, forKey: .log) ?? []).compactMap(\.value)
        hasAcknowledgedNotice = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedNotice) ?? false
        hideNamesInNotifications = try container.decodeIfPresent(Bool.self, forKey: .hideNamesInNotifications) ?? false
    }
}

private struct LossyMedicineValue<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}
