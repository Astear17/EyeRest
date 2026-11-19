import SwiftUI

struct RemindersView: View {
    @EnvironmentObject private var model: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Your reminders") {
                    ForEach(model.preferences.reminders) { reminder in
                        NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                            ReminderRow(reminder: reminder)
                        }
                    }
                }

                Section {
                    Text("Each category schedules independently. Changes are saved on this device and update the notification queue.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reminders")
        }
    }
}

struct ReminderRow: View {
    @EnvironmentObject private var model: AppViewModel
    let reminder: ReminderConfiguration

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: reminder.kind.symbol)
                .frame(width: 24)
                .foregroundStyle(.tint)

            VStack(alignment: .leading) {
                Text(reminder.kind.title)
                Text(reminder.isEnabled ? "Every \(reminder.intervalMinutes) min · \(reminder.nextFireDate?.eyeRestTime ?? "—")" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "\(reminder.kind.title) enabled",
                isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { value in
                        var changed = reminder
                        changed.isEnabled = value
                        model.update(changed)
                    }
                )
            )
            .labelsHidden()
        }
    }
}
