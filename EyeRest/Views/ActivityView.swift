import Charts
import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    rhythmCard
                    chartSection
                    historySection
                }
                .padding()
            }
            .navigationTitle("Activity")
        }
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Your rhythm", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            rhythmMetric(
                title: String(localized: "Current streak"),
                value: String.localizedStringWithFormat(String(localized: "%lld days"), model.currentStreak)
            )
            Divider()
            rhythmMetric(
                title: String(localized: "Best streak"),
                value: String.localizedStringWithFormat(String(localized: "%lld days"), model.bestStreak)
            )
            Divider()
            rhythmMetric(
                title: String(localized: "Total break time this week"),
                value: minutesText(model.totalBreakSecondsThisWeek)
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.title2.weight(.semibold))
            if chartDays.allSatisfy({ $0.total.completionCount == 0 }) {
                ContentUnavailableView(
                    "No breaks in the last 7 days",
                    systemImage: "chart.bar",
                    description: Text("Complete a break to begin your activity chart.")
                )
                .frame(maxWidth: .infinity)
            } else {
                Chart(chartPoints) { point in
                    BarMark(
                        x: .value(String(localized: "Day"), point.date, unit: .day),
                        y: .value(String(localized: "Completions"), point.count)
                    )
                    .foregroundStyle(by: .value(String(localized: "Kind"), point.kind.title))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 230)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Completions in the last 7 days")
                .accessibilityValue(chartAccessibilityDescription)
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title2.weight(.semibold))
            if historyGroups.isEmpty {
                ContentUnavailableView(
                    "No activity in the last 30 days",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed breaks will appear here.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(historyGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.events) { event in
                            historyRow(event)
                        }
                    }
                }
            }
        }
    }

    private func rhythmMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func historyRow(_ event: ActivityEvent) -> some View {
        let time = event.completedAt.formatted(.dateTime.hour().minute())
        let duration = durationText(event.durationSeconds)
        let source = event.source.localizedTitle
        return VStack(alignment: .leading, spacing: 6) {
            Label(event.kind.title, systemImage: event.kind.symbol)
                .font(.headline)
            Text(time)
            Text(duration)
            Text(source)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedStringWithFormat(
            String(localized: "Activity: %@, %@, %@, %@"),
            event.kind.title,
            time,
            duration,
            source
        ))
    }

    private var chartDays: [ChartDay] {
        model.activityLog.totalsForLast(days: 7).compactMap { total in
            guard let date = date(from: total.dayKey) else { return nil }
            return ChartDay(date: date, total: total)
        }
    }

    private var chartPoints: [ChartPoint] {
        chartDays.flatMap { day in
            ReminderKind.allCases.map { kind in
                ChartPoint(
                    dayKey: day.total.dayKey,
                    date: day.date,
                    kind: kind,
                    count: day.total.countsByKind[kind, default: 0]
                )
            }
        }
    }

    private var chartAccessibilityDescription: String {
        let details = chartDays.map { day in
            let date = day.date.formatted(.dateTime.weekday(.wide))
            let kinds = ReminderKind.allCases.compactMap { kind -> String? in
                let count = day.total.countsByKind[kind, default: 0]
                guard count > 0 else { return nil }
                return String.localizedStringWithFormat(String(localized: "%@: %lld completions"), kind.title, count)
            }.joined(separator: ", ")
            return kinds.isEmpty ? date : "\(date) — \(kinds)"
        }.joined(separator: ", ")
        return String.localizedStringWithFormat(String(localized: "Last 7 days: %@"), details)
    }

    private var historyGroups: [HistoryGroup] {
        let grouped = Dictionary(grouping: model.activityLog.recentEvents(days: 30), by: \.dayKey)
        return grouped.compactMap { dayKey, events in
            guard let date = date(from: dayKey) else { return nil }
            return HistoryGroup(dayKey: dayKey, date: date, events: events.sorted { $0.completedAt > $1.completedAt })
        }.sorted { $0.dayKey > $1.dayKey }
    }

    private func date(from dayKey: String) -> Date? {
        let values = dayKey.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return Calendar.autoupdatingCurrent.date(from: DateComponents(
            timeZone: Calendar.autoupdatingCurrent.timeZone,
            year: values[0],
            month: values[1],
            day: values[2],
            hour: 12
        ))
    }

    private func minutesText(_ seconds: Int) -> String {
        let minutes = (Double(seconds) / 60).formatted(.number.precision(.fractionLength(0...1)))
        return String.localizedStringWithFormat(String(localized: "%@ min"), minutes)
    }

    private func durationText(_ seconds: Int) -> String {
        if seconds >= 60, seconds.isMultiple(of: 60) {
            return String.localizedStringWithFormat(String(localized: "%lld min"), seconds / 60)
        }
        return String.localizedStringWithFormat(String(localized: "%lld sec"), seconds)
    }
}

private struct ChartDay {
    let date: Date
    let total: DailyTotal
}

private struct ChartPoint: Identifiable {
    let dayKey: String
    let date: Date
    let kind: ReminderKind
    let count: Int
    var id: String { "\(dayKey)-\(kind.rawValue)" }
}

private struct HistoryGroup: Identifiable {
    let dayKey: String
    let date: Date
    let events: [ActivityEvent]
    var id: String { dayKey }
}

private extension ActivitySource {
    var localizedTitle: String {
        switch self {
        case .guided: String(localized: "Guided")
        case .notificationAction: String(localized: "Notification action")
        case .manual: String(localized: "Manual")
        case .legacy: String(localized: "Legacy import")
        }
    }
}
