import Foundation

struct Completion: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ReminderKind
    let completedAt: Date

    init(id: UUID = UUID(), kind: ReminderKind, completedAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.completedAt = completedAt
    }
}

enum ActivitySource: String, Codable, CaseIterable {
    case guided
    case notificationAction
    case manual
    case legacy
}

struct ActivityEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ReminderKind
    let activityID: String?
    let completedAt: Date
    let dayKey: String
    let durationSeconds: Int
    let source: ActivitySource

    init(
        id: UUID = UUID(),
        kind: ReminderKind,
        activityID: String? = nil,
        completedAt: Date = .now,
        dayKey: String? = nil,
        durationSeconds: Int = 0,
        source: ActivitySource,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.id = id
        self.kind = kind
        self.activityID = activityID
        self.completedAt = completedAt
        self.dayKey = dayKey ?? Self.dayKey(for: completedAt, calendar: calendar)
        self.durationSeconds = max(0, durationSeconds)
        self.source = source
    }

    static func dayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

struct DailyTotal: Codable, Identifiable, Equatable {
    let dayKey: String
    var countsByKind: [ReminderKind: Int]
    var seconds: Int
    var id: String { dayKey }

    init(dayKey: String, countsByKind: [ReminderKind: Int] = [:], seconds: Int = 0) {
        self.dayKey = dayKey
        self.countsByKind = countsByKind
        self.seconds = max(0, seconds)
    }

    var completionCount: Int { countsByKind.values.reduce(0, +) }
}

struct ActivityLog: Codable, Equatable {
    private(set) var events: [ActivityEvent]
    private(set) var dailyTotals: [DailyTotal]

    init(events: [ActivityEvent] = [], dailyTotals: [DailyTotal] = []) {
        self.events = events
        self.dailyTotals = dailyTotals
    }

    @discardableResult
    mutating func append(_ event: ActivityEvent) -> Bool {
        guard !events.contains(where: { $0.id == event.id }) else { return false }
        events.append(event)
        if let index = dailyTotals.firstIndex(where: { $0.dayKey == event.dayKey }) {
            dailyTotals[index].countsByKind[event.kind, default: 0] += 1
            dailyTotals[index].seconds += event.durationSeconds
        } else {
            dailyTotals.append(DailyTotal(
                dayKey: event.dayKey,
                countsByKind: [event.kind: 1],
                seconds: event.durationSeconds
            ))
        }
        dailyTotals.sort { $0.dayKey < $1.dayKey }
        return true
    }

    mutating func pruneEvents(olderThanDays days: Int = 365, asOf now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        guard let cutoff = calendar.date(byAdding: .day, value: -max(0, days), to: now) else { return }
        events.removeAll { $0.completedAt < cutoff }
    }

    func todayCount(asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Int {
        total(for: ActivityEvent.dayKey(for: date, calendar: calendar))?.completionCount ?? 0
    }

    func currentStreak(asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let completed = completedDayKeys
        var cursor = calendar.startOfDay(for: date)
        let todayKey = ActivityEvent.dayKey(for: cursor, calendar: calendar)
        if !completed.contains(todayKey) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var result = 0
        while completed.contains(ActivityEvent.dayKey(for: cursor, calendar: calendar)) {
            result += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }

    func bestStreak(calendar: Calendar = .autoupdatingCurrent) -> Int {
        let keys = completedDayKeys.sorted()
        guard let first = keys.first, var previous = Self.date(from: first, calendar: calendar) else { return 0 }
        var best = 1
        var current = 1
        for key in keys.dropFirst() {
            guard let date = Self.date(from: key, calendar: calendar) else { continue }
            let expected = calendar.date(byAdding: .day, value: 1, to: previous)
            if let expected, ActivityEvent.dayKey(for: expected, calendar: calendar) == key {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = date
        }
        return best
    }

    func weekTotals(asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [DailyTotal] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let startKey = ActivityEvent.dayKey(for: interval.start, calendar: calendar)
        let endDate = calendar.date(byAdding: .day, value: 7, to: interval.start) ?? interval.end
        let endKey = ActivityEvent.dayKey(for: endDate, calendar: calendar)
        return dailyTotals.filter { $0.dayKey >= startKey && $0.dayKey < endKey }
    }

    func totalBreakSeconds(asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Int {
        weekTotals(asOf: date, calendar: calendar).reduce(0) { $0 + $1.seconds }
    }

    func totalsForLast(days: Int, asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [DailyTotal] {
        let count = max(0, days)
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = ActivityEvent.dayKey(for: day, calendar: calendar)
            return total(for: key) ?? DailyTotal(dayKey: key)
        }
    }

    func recentEvents(days: Int, asOf date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [ActivityEvent] {
        let count = max(0, days)
        guard count > 0,
              let cutoff = calendar.date(byAdding: .day, value: -(count - 1), to: calendar.startOfDay(for: date)) else { return [] }
        return events.filter { $0.completedAt >= cutoff && $0.completedAt <= date }.sorted { $0.completedAt > $1.completedAt }
    }

    func total(for dayKey: String) -> DailyTotal? {
        dailyTotals.first { $0.dayKey == dayKey }
    }

    private var completedDayKeys: Set<String> {
        Set(dailyTotals.filter { $0.completionCount > 0 }.map(\.dayKey))
    }

    private static func date(from dayKey: String, calendar: Calendar) -> Date? {
        let pieces = dayKey.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: pieces[0],
            month: pieces[1],
            day: pieces[2],
            hour: 12
        ))
    }
}

final class ActivityStore {
    static let legacyCompletionsKey = "EyeRest.completions.v1"

    let fileURL: URL
    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = applicationSupport.appendingPathComponent("EyeRest", isDirectory: true)
                .appendingPathComponent("activity-v1.json")
        }
    }

    func load(asOf now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> ActivityLog {
        let loaded = loadFile()
        var log = loaded.log
        let eventCountBeforePruning = log.events.count
        log.pruneEvents(asOf: now, calendar: calendar)
        let migrated = migrateLegacyCompletions(into: &log, calendar: calendar)
        if loaded.needsSave || migrated || log.events.count != eventCountBeforePruning { try? save(log) }
        return log
    }

    func save(_ log: ActivityLog) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(log)
        try data.write(to: fileURL, options: .atomic)
    }

    private func loadFile() -> (log: ActivityLog, needsSave: Bool) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return (ActivityLog(), false) }
        do {
            return (try JSONDecoder().decode(ActivityLog.self, from: Data(contentsOf: fileURL)), false)
        } catch {
            if let data = try? Data(contentsOf: fileURL) {
                try? data.write(to: fileURL.appendingPathExtension("corrupt"), options: .atomic)
            }
            return (ActivityLog(), true)
        }
    }

    private func migrateLegacyCompletions(into log: inout ActivityLog, calendar: Calendar) -> Bool {
        guard let data = defaults.data(forKey: Self.legacyCompletionsKey),
              let decoded = try? JSONDecoder().decode([LossyCompletion].self, from: data) else { return false }
        var changed = false
        for completion in decoded.compactMap(\.value) {
            changed = log.append(ActivityEvent(
                id: completion.id,
                kind: completion.kind,
                completedAt: completion.completedAt,
                durationSeconds: 0,
                source: .legacy,
                calendar: calendar
            )) || changed
        }
        return changed
    }

    private struct LossyCompletion: Decodable {
        let value: Completion?
        init(from decoder: Decoder) throws { value = try? Completion(from: decoder) }
    }
}
