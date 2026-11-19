import SwiftUI
struct ReminderDetailView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var reminder: ReminderConfiguration
    init(reminder: ReminderConfiguration) { _reminder = State(initialValue: reminder) }
    var body: some View { Form { Section { Toggle("Enable reminder", isOn: $reminder.isEnabled); Stepper("Interval: \(reminder.intervalMinutes) minutes", value: $reminder.intervalMinutes, in: 5...360, step: 5); if let next = reminder.nextFireDate { LabeledContent("Next scheduled", value: next.eyeRestTime) } } header: { Text(reminder.kind.title) } footer: { Text("Notifications are scheduled as individual dates so quiet hours and time-zone changes can be respected.") }
        Section("Notification message") { TextEditor(text: $reminder.message).frame(minHeight: 100).accessibilityLabel("Custom notification message") }
    }.navigationTitle(reminder.kind.title).navigationBarTitleDisplayMode(.inline).onDisappear { model.update(reminder) } }
}
