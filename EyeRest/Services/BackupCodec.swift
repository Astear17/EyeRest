import Foundation

struct BackupReminder: Codable, Equatable {
    let kind: ReminderKind
    let isEnabled: Bool
    let intervalMinutes: Int
    let customMessage: String?
}

struct BackupSettings: Codable, Equatable {
    let reminders: [BackupReminder]
    let quietHours: QuietHours
    let priority: NotificationPriority
    let appearance: AppPreferences.Appearance
    let pausedUntil: Date?
    let activeDays: [Int]
    let snoozeMinutes: Int?
    let hapticsEnabled: Bool
    let hasCompletedWelcome: Bool

    init(preferences: AppPreferences) {
        reminders = preferences.reminders.map {
            BackupReminder(kind: $0.kind, isEnabled: $0.isEnabled, intervalMinutes: $0.intervalMinutes, customMessage: $0.customMessage)
        }
        quietHours = preferences.quietHours
        priority = preferences.priority
        appearance = preferences.appearance
        pausedUntil = preferences.pausedUntil
        activeDays = preferences.activeDays.sorted()
        snoozeMinutes = preferences.snoozeMinutes
        hapticsEnabled = preferences.hapticsEnabled
        hasCompletedWelcome = preferences.hasCompletedWelcome
    }

    func preferences() -> AppPreferences {
        AppPreferences(
            reminders: reminders.map {
                ReminderConfiguration(
                    kind: $0.kind,
                    isEnabled: $0.isEnabled,
                    intervalMinutes: $0.intervalMinutes,
                    customMessage: $0.customMessage,
                    nextFireDate: nil
                )
            },
            quietHours: quietHours,
            priority: priority,
            appearance: appearance,
            pausedUntil: pausedUntil,
            activeDays: Set(activeDays),
            snoozeMinutes: snoozeMinutes,
            hapticsEnabled: hapticsEnabled,
            hasCompletedWelcome: hasCompletedWelcome
        )
    }
}

struct BackupActivity: Codable, Equatable {
    let events: [ActivityEvent]
    let dailyTotals: [BackupDailyTotal]

    init(log: ActivityLog) {
        events = log.events
        dailyTotals = log.dailyTotals.map(BackupDailyTotal.init)
    }

    var log: ActivityLog { ActivityLog(events: events, dailyTotals: dailyTotals.map(\.dailyTotal)) }
}

struct BackupDailyTotal: Codable, Equatable {
    let dayKey: String
    let countsByKind: [String: Int]
    let seconds: Int

    init(_ total: DailyTotal) {
        dayKey = total.dayKey
        countsByKind = Dictionary(uniqueKeysWithValues: total.countsByKind.map { ($0.key.rawValue, $0.value) })
        seconds = total.seconds
    }

    var dailyTotal: DailyTotal {
        DailyTotal(
            dayKey: dayKey,
            countsByKind: Dictionary(uniqueKeysWithValues: countsByKind.compactMap { key, value in
                ReminderKind(rawValue: key).map { ($0, value) }
            }),
            seconds: seconds
        )
    }
}

struct EyeRestBackup: Codable, Equatable {
    let format: String
    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let settings: BackupSettings
    let activity: BackupActivity
    let payloadSHA256: String
}

struct BackupPreview: Equatable {
    let backup: EyeRestBackup
    let eventCount: Int
    let dailyTotalCount: Int
    let earliestDate: Date?
    let latestDate: Date?
}

enum BackupCodecError: Error, Equatable {
    case invalidJSON
    case wrongFormat
    case newerSchema(Int)
    case checksumMismatch
    case invalidValue(String)
}

enum BackupCodec {
    static let format = "com.astear17.eyerest.backup"
    static let schemaVersion = 1

    static func encode(
        preferences: AppPreferences,
        activityLog: ActivityLog,
        appVersion: String,
        exportedAt: Date = .now
    ) throws -> Data {
        let unsigned = UnsignedBackup(
            format: format,
            schemaVersion: schemaVersion,
            appVersion: appVersion,
            exportedAt: exportedAt,
            settings: BackupSettings(preferences: preferences),
            activity: BackupActivity(log: activityLog)
        )
        let checksum = SHA256.hexDigest(try canonicalData(unsigned))
        let backup = EyeRestBackup(
            format: unsigned.format,
            schemaVersion: unsigned.schemaVersion,
            appVersion: unsigned.appVersion,
            exportedAt: unsigned.exportedAt,
            settings: unsigned.settings,
            activity: unsigned.activity,
            payloadSHA256: checksum
        )
        return try canonicalData(backup)
    }

    static func decode(_ data: Data) throws -> BackupPreview {
        let backup: EyeRestBackup
        do { backup = try decoder.decode(EyeRestBackup.self, from: data) }
        catch { throw BackupCodecError.invalidJSON }
        guard backup.format == format else { throw BackupCodecError.wrongFormat }
        guard backup.schemaVersion <= schemaVersion else { throw BackupCodecError.newerSchema(backup.schemaVersion) }
        guard backup.schemaVersion == schemaVersion else { throw BackupCodecError.invalidValue("schemaVersion") }
        let unsigned = UnsignedBackup(
            format: backup.format,
            schemaVersion: backup.schemaVersion,
            appVersion: backup.appVersion,
            exportedAt: backup.exportedAt,
            settings: backup.settings,
            activity: backup.activity
        )
        guard SHA256.hexDigest(try canonicalData(unsigned)) == backup.payloadSHA256.lowercased() else {
            throw BackupCodecError.checksumMismatch
        }
        try validate(backup)
        let dates = backup.activity.events.map(\.completedAt)
        return BackupPreview(
            backup: backup,
            eventCount: backup.activity.events.count,
            dailyTotalCount: backup.activity.dailyTotals.count,
            earliestDate: dates.min(),
            latestDate: dates.max()
        )
    }

    static func mergedActivity(current: ActivityLog, imported: ActivityLog) -> ActivityLog {
        var eventsByID = Dictionary(uniqueKeysWithValues: current.events.map { ($0.id, $0) })
        for event in imported.events { eventsByID[event.id] = eventsByID[event.id] ?? event }

        var totalsByDay = Dictionary(uniqueKeysWithValues: current.dailyTotals.map { ($0.dayKey, $0) })
        for total in imported.dailyTotals {
            guard var existing = totalsByDay[total.dayKey] else {
                totalsByDay[total.dayKey] = total
                continue
            }
            for kind in ReminderKind.allCases {
                existing.countsByKind[kind] = max(existing.countsByKind[kind, default: 0], total.countsByKind[kind, default: 0])
            }
            existing.seconds = max(existing.seconds, total.seconds)
            totalsByDay[total.dayKey] = existing
        }
        return ActivityLog(
            events: eventsByID.values.sorted { $0.completedAt < $1.completedAt },
            dailyTotals: totalsByDay.values.sorted { $0.dayKey < $1.dayKey }
        )
    }

    private static func validate(_ backup: EyeRestBackup) throws {
        guard !backup.appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              backup.appVersion.count <= 64 else { throw BackupCodecError.invalidValue("appVersion") }
        guard backup.settings.reminders.count == ReminderKind.allCases.count,
              Set(backup.settings.reminders.map(\.kind)) == Set(ReminderKind.allCases) else {
            throw BackupCodecError.invalidValue("reminders")
        }
        for reminder in backup.settings.reminders {
            guard (5...360).contains(reminder.intervalMinutes) else { throw BackupCodecError.invalidValue("intervalMinutes") }
            guard (reminder.customMessage?.count ?? 0) <= 200 else { throw BackupCodecError.invalidValue("customMessage") }
        }
        guard (0..<1440).contains(backup.settings.quietHours.startMinutes),
              (0..<1440).contains(backup.settings.quietHours.endMinutes) else {
            throw BackupCodecError.invalidValue("quietHours")
        }
        guard !backup.settings.activeDays.isEmpty,
              Set(backup.settings.activeDays).count == backup.settings.activeDays.count,
              backup.settings.activeDays.allSatisfy({ (1...7).contains($0) }) else {
            throw BackupCodecError.invalidValue("activeDays")
        }
        if let snooze = backup.settings.snoozeMinutes, ![5, 10, 15].contains(snooze) {
            throw BackupCodecError.invalidValue("snoozeMinutes")
        }
        guard Set(backup.activity.events.map(\.id)).count == backup.activity.events.count else {
            throw BackupCodecError.invalidValue("duplicateEventID")
        }
        guard Set(backup.activity.dailyTotals.map(\.dayKey)).count == backup.activity.dailyTotals.count else {
            throw BackupCodecError.invalidValue("duplicateDayKey")
        }
        for event in backup.activity.events {
            guard validDayKey(event.dayKey), (0...86_400).contains(event.durationSeconds) else {
                throw BackupCodecError.invalidValue("event")
            }
        }
        for total in backup.activity.dailyTotals {
            guard validDayKey(total.dayKey), (0...31_536_000).contains(total.seconds),
                  total.countsByKind.keys.allSatisfy({ ReminderKind(rawValue: $0) != nil }),
                  total.countsByKind.values.allSatisfy({ (0...1_000_000).contains($0) }) else {
                throw BackupCodecError.invalidValue("dailyTotal")
            }
        }
    }

    private static func validDayKey(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) != nil
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private static func canonicalData<T: Encodable>(_ value: T) throws -> Data { try encoder.encode(value) }

    private struct UnsignedBackup: Codable {
        let format: String
        let schemaVersion: Int
        let appVersion: String
        let exportedAt: Date
        let settings: BackupSettings
        let activity: BackupActivity
    }
}

private enum SHA256 {
    private static let initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private static let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func hexDigest(_ data: Data) -> String {
        var message = Array(data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) { message.append(UInt8((bitLength >> UInt64(shift)) & 0xff)) }
        var hash = initial
        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 64)
            for index in 0..<16 {
                let base = offset + index * 4
                words[index] = UInt32(message[base]) << 24 | UInt32(message[base + 1]) << 16 | UInt32(message[base + 2]) << 8 | UInt32(message[base + 3])
            }
            for index in 16..<64 {
                let s0 = rotate(words[index - 15], by: 7) ^ rotate(words[index - 15], by: 18) ^ (words[index - 15] >> 3)
                let s1 = rotate(words[index - 2], by: 17) ^ rotate(words[index - 2], by: 19) ^ (words[index - 2] >> 10)
                words[index] = words[index - 16] &+ s0 &+ words[index - 7] &+ s1
            }
            var a = hash[0], b = hash[1], c = hash[2], d = hash[3]
            var e = hash[4], f = hash[5], g = hash[6], h = hash[7]
            for index in 0..<64 {
                let sum1 = rotate(e, by: 6) ^ rotate(e, by: 11) ^ rotate(e, by: 25)
                let choice = (e & f) ^ ((~e) & g)
                let temp1 = h &+ sum1 &+ choice &+ constants[index] &+ words[index]
                let sum0 = rotate(a, by: 2) ^ rotate(a, by: 13) ^ rotate(a, by: 22)
                let majority = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = sum0 &+ majority
                h = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            hash[0] &+= a; hash[1] &+= b; hash[2] &+= c; hash[3] &+= d
            hash[4] &+= e; hash[5] &+= f; hash[6] &+= g; hash[7] &+= h
        }
        return hash.map { String(format: "%08x", $0) }.joined()
    }

    private static func rotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
    }
}
