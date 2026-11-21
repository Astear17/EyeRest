import SwiftUI
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.openURL) private var openURL
    @Binding var settingsTab: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if model.authorizationStatus == .denied {
                        notificationBanner
                    }
                    reminderSummary
                    controls
                    Divider()
                    HStack {
                        Label("Today", systemImage: "checkmark.circle")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(model.todayCount) completed").fontWeight(.semibold)
                            Text(String.localizedStringWithFormat(String(localized: "%lld-day streak"), model.currentStreak))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.headline)
                    if let queuedUntil = model.queuedUntil {
                        Text("Reminders are queued until \(queuedUntil.eyeRestQueueDate). Open EyeRest to keep them going.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text("Your reminders are scheduled privately on this iPhone. EyeRest does not collect or send any data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("EyeRest")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settingsTab = 2 } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Open settings")
                }
            }
        }
    }

    private var reminderSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next reminder").font(.subheadline).foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let text = countdownText(at: context.date)
                Text(text)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel("Countdown \(text)")
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Text(subtitle).font(.headline).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Menu {
                if model.isPaused { Button("Resume reminders") { model.resumeReminders() } }
                Button("Pause for 1 hour") { model.pause(for: 60 * 60) }
                Button("Pause for rest of today") { model.pauseForRestOfToday() }
                Button("Pause until I resume") { model.pause(for: nil) }
            } label: {
                Label {
                    Text(model.isPaused ? String(localized: "Resume") : String(localized: "Pause"))
                } icon: {
                    Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            Button { model.requestBreak(.eyeRest) } label: {
                Label("Eye rest now", systemImage: "eye").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Menu {
                ForEach(BreakActivity.all) { activity in
                    Button { model.requestBreak(activity) } label: {
                        Label(activity.title, systemImage: activity.symbol)
                    }
                }
            } label: {
                Label("Start a break", systemImage: "play.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }

    private var notificationBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notifications are off. EyeRest can't remind you until you turn them on.", systemImage: "bell.slash.fill")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private var subtitle: String {
        if let pausedUntil = model.preferences.pausedUntil, pausedUntil > .now {
            if pausedUntil == .distantFuture { return String(localized: "Reminders are paused") }
            return String.localizedStringWithFormat(String(localized: "Paused until %@"), pausedUntil.formatted(date: .omitted, time: .shortened))
        }
        guard let reminder = model.nextReminder else { return String(localized: "Enable a reminder to begin") }
        return "\(reminder.kind.title) · \(reminder.nextFireDate?.eyeRestTime ?? "")"
    }

    private func countdownText(at date: Date) -> String {
        if model.isPaused { return String(localized: "Paused") }
        guard !model.enabledReminders.isEmpty else { return "--:--:--" }
        return model.countdownText(to: model.nextDate, now: date)
    }
}
