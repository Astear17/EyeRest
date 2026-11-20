import SwiftUI

struct ReminderDetailView: View {
    @EnvironmentObject private var model: AppViewModel
    let kind: ReminderKind
    @State private var isEnabled: Bool
    @State private var intervalMinutes: Int
    @State private var customMessage: String
    @State private var messageTask: Task<Void, Never>?

    init(reminder: ReminderConfiguration) {
        kind = reminder.kind
        _isEnabled = State(initialValue: reminder.isEnabled)
        _intervalMinutes = State(initialValue: reminder.intervalMinutes)
        _customMessage = State(initialValue: reminder.customMessage ?? "")
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable reminder", isOn: $isEnabled)
                Stepper("Interval: \(intervalMinutes) minutes", value: $intervalMinutes, in: 5...360, step: 5)
                if let next = currentReminder?.nextFireDate {
                    LabeledContent("Next scheduled", value: next.eyeRestTime)
                }
            } header: {
                Text(kind.title)
            } footer: {
                Text("Notifications are scheduled as individual dates so quiet hours and time-zone changes can be respected.")
            }

            Section("Notification message") {
                ZStack(alignment: .topLeading) {
                    if customMessage.isEmpty {
                        Text(kind.defaultMessage)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: messageBinding)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Custom notification message")
                }
                Text(kind.defaultMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isEnabled) { _, _ in commit() }
        .onChange(of: intervalMinutes) { _, _ in commit() }
        .onChange(of: customMessage) { _, _ in debounceMessageCommit() }
        .onDisappear {
            messageTask?.cancel()
            commit()
        }
    }

    private var currentReminder: ReminderConfiguration? {
        model.preferences.reminders.first { $0.kind == kind }
    }

    private var messageBinding: Binding<String> {
        Binding(
            get: { customMessage },
            set: { customMessage = String($0.prefix(200)) }
        )
    }

    private func debounceMessageCommit() {
        messageTask?.cancel()
        messageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            commit()
        }
    }

    private func commit() {
        model.update(kind: kind, isEnabled: isEnabled, intervalMinutes: intervalMinutes, customMessage: customMessage)
    }
}
