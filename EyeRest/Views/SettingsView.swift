import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.openURL) private var openURL
    @State private var showingResetConfirmation = false

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

                Section("Appearance") {
                    Picker("Theme", selection: Binding(get: { model.preferences.appearance }, set: { value in model.updatePreferences { $0.appearance = value } })) {
                        ForEach(AppPreferences.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
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
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
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
