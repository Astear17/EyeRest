import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.openURL) private var openURL
    @State private var showingResetConfirmation = false
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupDocument: BackupDocument?
    @State private var importPreview: BackupPreview?
    @State private var dataError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Picker("Interruption level", selection: Binding(get: { model.preferences.priority }, set: { choice in model.updatePreferences { $0.priority = choice } })) {
                        ForEach(NotificationPriority.allCases) { Text($0.title).tag($0) }
                    }
                    if !model.canScheduleNotifications {
                        Button("Request notification permission") {
                            Task { await model.requestNotificationAuthorization() }
                        }
                    }
                    Text("Quiet delivers the alert without sound.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.preferences.priority == .timeSensitive && !model.isTimeSensitiveAvailable {
                        Text("Time Sensitive isn't available for this install, so reminders arrive as normal notifications.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Quiet hours") {
                    Toggle("Enable quiet hours", isOn: Binding(get: { model.preferences.quietHours.enabled }, set: { value in model.updatePreferences { $0.quietHours.enabled = value } }))
                    if model.preferences.quietHours.enabled {
                        DatePicker("Start", selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
                    }
                }

                Section("Schedule") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(1...7, id: \.self) { weekday in
                                Button {
                                    model.updatePreferences { preferences in
                                        if preferences.activeDays.contains(weekday), preferences.activeDays.count > 1 { preferences.activeDays.remove(weekday) }
                                        else { preferences.activeDays.insert(weekday) }
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        if model.preferences.activeDays.contains(weekday) { Image(systemName: "checkmark") }
                                        Text(Calendar.autoupdatingCurrent.shortWeekdaySymbols[weekday - 1])
                                    }
                                        .frame(minWidth: 36, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(model.preferences.activeDays.contains(weekday) ? .accentColor : .secondary)
                            }
                        }
                    }
                    Button("Work week") {
                        model.updatePreferences {
                            $0.activeDays = [2, 3, 4, 5, 6]
                            $0.quietHours = QuietHours(enabled: true, startMinutes: 18 * 60, endMinutes: 9 * 60)
                        }
                    }
                    Picker("Snooze", selection: Binding(get: { model.preferences.snoozeMinutes }, set: { value in model.updatePreferences { $0.snoozeMinutes = value } })) {
                        Text("Off").tag(Int?.none)
                        ForEach([5, 10, 15], id: \.self) { Text("\($0) minutes").tag(Int?.some($0)) }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: Binding(get: { model.preferences.appearance }, set: { value in model.updatePreferences { $0.appearance = value } })) {
                        ForEach(AppPreferences.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Haptics", isOn: Binding(
                        get: { model.preferences.hapticsEnabled },
                        set: { value in model.updatePreferences { $0.hapticsEnabled = value } }
                    ))
                }

                Section("Data") {
                    Button("Export backup") { prepareExport() }
                    Button("Import backup") { showingImporter = true }
                    if model.canUndoImport {
                        Button("Undo last import") {
                            do { try model.undoLastImport() }
                            catch { dataError = String(localized: "The previous data could not be restored.") }
                        }
                    }
                    Text("Backups include settings and activity history. Notification permission and scheduled alerts are never included.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Restore default intervals", role: .destructive) { showingResetConfirmation = true }
                } footer: {
                    Text("This restores each reminder's interval, message and on/off state. Quiet hours, theme and history are kept.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("EyeRest works fully offline. No analytics, advertising, accounts, tracking, or external services.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Restore default reminders?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Restore", role: .destructive) { model.resetDefaults() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Notifications are off", isPresented: $model.showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications for EyeRest in iPhone Settings to receive reminders.")
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                if case .failure = result { dataError = String(localized: "The backup could not be exported.") }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { throw CocoaError(.fileReadNoSuchFile) }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    importPreview = try model.previewBackup(Data(contentsOf: url))
                } catch let error as BackupCodecError {
                    dataError = importErrorMessage(error)
                } catch {
                    dataError = String(localized: "This file is not a valid EyeRest backup.")
                }
            }
            .confirmationDialog("Import this backup?", isPresented: Binding(
                get: { importPreview != nil },
                set: { if !$0 { importPreview = nil } }
            ), titleVisibility: .visible) {
                Button("Import and replace settings") {
                    guard let preview = importPreview else { return }
                    do { try model.applyBackup(preview) }
                    catch { dataError = String(localized: "The backup could not be imported. Your data was not changed.") }
                    importPreview = nil
                }
                Button("Cancel", role: .cancel) { importPreview = nil }
            } message: {
                if let preview = importPreview {
                    Text(importSummary(preview))
                }
            }
            .alert("Data could not be updated", isPresented: Binding(
                get: { dataError != nil },
                set: { if !$0 { dataError = nil } }
            )) {
                Button("OK") { dataError = nil }
            } message: {
                Text(dataError ?? "")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var backupFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "EyeRest-Backup-\(formatter.string(from: .now)).json"
    }

    private func prepareExport() {
        do {
            backupDocument = BackupDocument(data: try model.backupData(appVersion: appVersion))
            showingExporter = true
        } catch {
            dataError = String(localized: "The backup could not be exported.")
        }
    }

    private func importSummary(_ preview: BackupPreview) -> String {
        let range: String
        if let earliest = preview.earliestDate, let latest = preview.latestDate {
            range = "\(earliest.formatted(date: .abbreviated, time: .omitted)) – \(latest.formatted(date: .abbreviated, time: .omitted))"
        } else {
            range = String(localized: "No activity dates")
        }
        return String.localizedStringWithFormat(
            String(localized: "%lld activities across %lld days\n%@"),
            preview.eventCount,
            preview.dailyTotalCount,
            range
        )
    }

    private func importErrorMessage(_ error: BackupCodecError) -> String {
        switch error {
        case .newerSchema:
            return String(localized: "This backup was created by a newer version of EyeRest.")
        case .checksumMismatch:
            return String(localized: "This backup is damaged or has been changed.")
        default:
            return String(localized: "This file is not a valid EyeRest backup.")
        }
    }

    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(
            get: {
                let minutes = start ? model.preferences.quietHours.startMinutes : model.preferences.quietHours.endMinutes
                return Calendar.autoupdatingCurrent.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let calendar = Calendar.autoupdatingCurrent
                let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
                model.updatePreferences {
                    if start { $0.quietHours.startMinutes = minutes }
                    else { $0.quietHours.endMinutes = minutes }
                }
            }
        )
    }
}
