import SwiftUI

struct MedicineView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var editorTarget: MedicineEditorTarget?
    @State private var showingNotice = false
    @State private var historyFilter: UUID?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    warningSection
                    todaySection
                    medicinesSection
                    historySection
                }
                .onAppear { openRequestedDose(using: proxy) }
                .onChange(of: model.requestedMedicineDose) { _, _ in openRequestedDose(using: proxy) }
            }
            .navigationTitle("Medicine")
            .sheet(item: $editorTarget) { target in
                MedicineEditorView(reminder: target.reminder)
                    .environmentObject(model)
            }
            .alert("Before you add a reminder", isPresented: $showingNotice) {
                Button("Continue") {
                    model.acknowledgeMedicineNotice()
                    editorTarget = MedicineEditorTarget(reminder: nil)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("EyeRest medicine reminders are a convenience. Notifications can be delayed or missed (for example by Focus modes, notification settings or an expired app signature). Do not rely on EyeRest alone for important medication, and follow your healthcare professional's advice.")
            }
        }
    }

    @ViewBuilder
    private var warningSection: some View {
        Section {
            Label(
                "Medicine reminders are a convenience. Do not rely on EyeRest alone for important medication.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            if !model.canScheduleNotifications {
                Label("Notifications are off. Medicine reminders cannot alert you.", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
            }
            if let queuedUntil = model.medicineQueuedUntil,
               queuedUntil < (Calendar.autoupdatingCurrent.date(byAdding: .day, value: 7, to: .now) ?? .now) {
                Text(String.localizedStringWithFormat(
                    String(localized: "Medicine reminders are queued until %@."),
                    queuedUntil.formatted(date: .abbreviated, time: .shortened)
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        Section("Today") {
            if todayOccurrences.isEmpty {
                ContentUnavailableView(
                    "No medicine reminders today",
                    systemImage: "pills",
                    description: Text("Today's scheduled doses will appear here.")
                )
            } else {
                ForEach(todayOccurrences) { occurrence in
                    MedicineDoseRow(occurrence: occurrence)
                        .environmentObject(model)
                        .id(occurrence.id)
                }
            }
        }
    }

    private var medicinesSection: some View {
        Section {
            if model.medicineData.reminders.isEmpty {
                ContentUnavailableView(
                    "No medicines yet",
                    systemImage: "pills",
                    description: Text("Add a medicine and choose when EyeRest should remind you.")
                )
            } else {
                ForEach(model.medicineData.reminders) { reminder in
                    Button {
                        editorTarget = MedicineEditorTarget(reminder: reminder)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.name).font(.headline)
                                Text(reminderSummary(reminder)).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(
                                get: { reminder.isEnabled },
                                set: { model.setMedicineReminder(reminder.id, enabled: $0) }
                            ))
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens medicine reminder settings")
                }
            }
        } header: {
            HStack {
                Text("My medicines")
                Spacer()
                Button("Add") { beginAdding() }
                    .accessibilityLabel("Add medicine")
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("History") {
            if !model.medicineData.reminders.isEmpty {
                Picker("Filter by medicine", selection: $historyFilter) {
                    Text("All medicines").tag(UUID?.none)
                    ForEach(model.medicineData.reminders) { reminder in
                        Text(reminder.name).tag(UUID?.some(reminder.id))
                    }
                }
            }
            if historyGroups.isEmpty {
                ContentUnavailableView(
                    "No medicine history",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Taken, skipped and snoozed events will appear here.")
                )
            } else {
                ForEach(historyGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.nameSnapshot).font(.headline)
                                Text(entry.scheduledAt, format: .dateTime.hour().minute())
                                Text(historyAction(entry))
                                Text(String.localizedStringWithFormat(
                                    String(localized: "Marked %@"),
                                    entry.markedAt.formatted(date: .omitted, time: .shortened)
                                ))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private var todayOccurrences: [MedicineOccurrence] {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? .now
        return MedicineSchedule.occurrences(of: model.medicineData.reminders, from: start, to: end, calendar: calendar)
    }

    private var historyGroups: [MedicineHistoryGroup] {
        let entries = model.medicineData.log.filter { historyFilter == nil || $0.medicineID == historyFilter }
        let grouped = Dictionary(grouping: entries) { MedicineDay($0.markedAt) }
        return grouped.map { day, values in
            MedicineHistoryGroup(
                day: day,
                date: day.date ?? values[0].markedAt,
                entries: values.sorted { $0.markedAt > $1.markedAt }
            )
        }.sorted { $0.day > $1.day }
    }

    private func beginAdding() {
        if model.medicineData.hasAcknowledgedNotice { editorTarget = MedicineEditorTarget(reminder: nil) }
        else { showingNotice = true }
    }

    private func openRequestedDose(using proxy: ScrollViewProxy) {
        guard let requested = model.requestedMedicineDose else { return }
        withAnimation { proxy.scrollTo(requested, anchor: .center) }
        model.consumeRequestedMedicineDose()
    }

    private func reminderSummary(_ reminder: MedicineReminder) -> String {
        let times = reminder.times.map { minute in
            let date = Calendar.autoupdatingCurrent.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
            return date.formatted(date: .omitted, time: .shortened)
        }.joined(separator: ", ")
        return "\(repeatTitle(reminder.repeatRule)) · \(times)"
    }

    private func repeatTitle(_ rule: MedicineRepeatRule) -> String {
        switch rule {
        case .none: String(localized: "Does not repeat")
        case .daily: String(localized: "Every day")
        case .weekdays: String(localized: "Specific days")
        }
    }

    private func historyAction(_ entry: MedicineLogEntry) -> String {
        switch entry.action {
        case .taken: String(localized: "Taken")
        case .skipped: String(localized: "Skipped")
        case .snoozed: String.localizedStringWithFormat(String(localized: "Snoozed for %lld min"), entry.snoozeMinutes ?? 0)
        }
    }
}

private struct MedicineDoseRow: View {
    @EnvironmentObject private var model: AppViewModel
    let occurrence: MedicineOccurrence

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(occurrence.name).font(.headline)
                    Text(occurrence.scheduledAt, format: .dateTime.hour().minute())
                }
                Spacer()
                Label(statusText, systemImage: statusSymbol)
                    .font(.caption.weight(.semibold))
            }
            if allowsActions {
                ViewThatFits {
                    HStack { actionButtons }
                    VStack(alignment: .leading) { actionButtons }
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Taken") { mark(.taken) }.frame(minHeight: 44)
        Button("Skipped") { mark(.skipped) }.frame(minHeight: 44)
        Button("Snooze") { mark(.snoozed) }.frame(minHeight: 44)
    }

    private var status: MedicineDoseStatus {
        MedicineSchedule.status(for: occurrence, log: model.medicineData.log)
    }
    private var allowsActions: Bool {
        switch status { case .taken, .skipped: false; default: true }
    }
    private var statusText: String {
        switch status {
        case .taken: String(localized: "Taken")
        case .skipped: String(localized: "Skipped")
        case let .snoozed(until): String.localizedStringWithFormat(String(localized: "Snoozed until %@"), until.formatted(date: .omitted, time: .shortened))
        case .upcoming: String(localized: "Upcoming")
        case .notRecorded: String(localized: "Not recorded")
        case .noOutcome: String(localized: "Not recorded")
        }
    }
    private var statusSymbol: String {
        switch status {
        case .taken: "checkmark.circle.fill"
        case .skipped: "forward.circle.fill"
        case .snoozed: "clock.badge"
        case .upcoming: "clock"
        case .notRecorded, .noOutcome: "questionmark.circle"
        }
    }
    private func mark(_ action: MedicineLogAction) {
        Task { await model.markMedicineDose(medicineID: occurrence.medicineID, scheduledAt: occurrence.scheduledAt, action: action) }
    }
}

private struct MedicineEditorView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let original: MedicineReminder?
    @State private var name: String
    @State private var times: [Date]
    @State private var repeatChoice: MedicineRepeatChoice
    @State private var weekdays: Set<Int>
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var snoozeMinutes: Int
    @State private var enabled: Bool
    @State private var validationMessage: String?

    init(reminder: MedicineReminder?) {
        original = reminder
        let calendar = Calendar.autoupdatingCurrent
        _name = State(initialValue: reminder?.name ?? "")
        _times = State(initialValue: (reminder?.times ?? [8 * 60]).map {
            calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: .now) ?? .now
        })
        switch reminder?.repeatRule ?? .daily {
        case .none: _repeatChoice = State(initialValue: .none); _weekdays = State(initialValue: [2, 3, 4, 5, 6])
        case .daily: _repeatChoice = State(initialValue: .daily); _weekdays = State(initialValue: [2, 3, 4, 5, 6])
        case let .weekdays(days): _repeatChoice = State(initialValue: .weekdays); _weekdays = State(initialValue: days)
        }
        _startDate = State(initialValue: reminder?.startDay.date ?? .now)
        _hasEndDate = State(initialValue: reminder?.endDay != nil)
        _endDate = State(initialValue: reminder?.endDay?.date ?? calendar.date(byAdding: .month, value: 1, to: .now) ?? .now)
        _snoozeMinutes = State(initialValue: reminder?.snoozeMinutes ?? 10)
        _enabled = State(initialValue: reminder?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Toggle("Enabled", isOn: $enabled)
                }
                Section("Times") {
                    ForEach(times.indices, id: \.self) { index in
                        DatePicker("Time \(index + 1)", selection: $times[index], displayedComponents: .hourAndMinute)
                    }
                    if times.count < 6 { Button("Add time") { times.append(.now) } }
                    if times.count > 1 { Button("Remove last time", role: .destructive) { times.removeLast() } }
                }
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatChoice) {
                        ForEach(MedicineRepeatChoice.allCases) { Text($0.title).tag($0) }
                    }
                    if repeatChoice == .weekdays { weekdayPicker }
                }
                Section("Dates") {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("End date", isOn: $hasEndDate)
                    if hasEndDate { DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date) }
                }
                Section("Snooze length") {
                    Picker("Snooze length", selection: $snoozeMinutes) {
                        ForEach([5, 10, 15], id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                }
                if let validationMessage { Text(validationMessage).foregroundStyle(.red) }
                if let original {
                    Section {
                        Button("Delete medicine", role: .destructive) {
                            model.deleteMedicineReminder(original.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? String(localized: "Add medicine") : String(localized: "Edit medicine"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private var weekdayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(1...7, id: \.self) { weekday in
                    let selected = weekdays.contains(weekday)
                    Button {
                        if selected, weekdays.count > 1 { weekdays.remove(weekday) }
                        else { weekdays.insert(weekday) }
                    } label: {
                        Text(Calendar.autoupdatingCurrent.shortWeekdaySymbols[weekday - 1]).frame(minWidth: 36, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? .accentColor : .secondary)
                    .accessibilityValue(selected ? String(localized: "Selected") : String(localized: "Not selected"))
                }
            }
        }
    }

    private func save() {
        let calendar = Calendar.autoupdatingCurrent
        let minutes = times.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        let repeatRule: MedicineRepeatRule
        switch repeatChoice {
        case .none: repeatRule = .none
        case .daily: repeatRule = .daily
        case .weekdays: repeatRule = .weekdays(weekdays)
        }
        do {
            let reminder = try MedicineReminder(
                id: original?.id ?? UUID(),
                name: name,
                times: minutes,
                repeatRule: repeatRule,
                startDay: MedicineDay(startDate, calendar: calendar),
                endDay: hasEndDate ? MedicineDay(endDate, calendar: calendar) : nil,
                isEnabled: enabled,
                snoozeMinutes: snoozeMinutes
            )
            model.saveMedicineReminder(reminder)
            dismiss()
        } catch MedicineValidationError.invalidName {
            validationMessage = String(localized: "Enter a name from 1 to 60 characters.")
        } catch MedicineValidationError.invalidTimes {
            validationMessage = String(localized: "Choose 1 to 6 different times.")
        } catch MedicineValidationError.invalidWeekdays {
            validationMessage = String(localized: "Choose at least one day.")
        } catch MedicineValidationError.invalidDateRange {
            validationMessage = String(localized: "End date must be on or after the start date.")
        } catch {
            validationMessage = String(localized: "Check the reminder details and try again.")
        }
    }
}

private enum MedicineRepeatChoice: String, CaseIterable, Identifiable {
    case none, daily, weekdays
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: String(localized: "Does not repeat")
        case .daily: String(localized: "Every day")
        case .weekdays: String(localized: "Specific days")
        }
    }
}

private struct MedicineEditorTarget: Identifiable {
    let id = UUID()
    let reminder: MedicineReminder?
}

private struct MedicineHistoryGroup: Identifiable {
    let day: MedicineDay
    let date: Date
    let entries: [MedicineLogEntry]
    var id: MedicineDay { day }
}

private extension MedicineDay {
    var date: Date? {
        Calendar.autoupdatingCurrent.date(from: DateComponents(
            timeZone: Calendar.autoupdatingCurrent.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
    }
}
