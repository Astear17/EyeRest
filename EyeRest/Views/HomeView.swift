import SwiftUI
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.openURL) private var openURL
    @Binding var settingsTab: Int
    @State private var showingEyeRestSession = false

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
                        Text("\(model.todayCount) completed").fontWeight(.semibold)
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
            .sheet(isPresented: $showingEyeRestSession) {
                EyeRestSessionView(isPresented: $showingEyeRestSession)
                    .environmentObject(model)
                    .interactiveDismissDisabled(true)
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
        HStack(spacing: 12) {
            Button { model.togglePause() } label: {
                Label {
                    Text(model.isPaused ? String(localized: "Resume") : String(localized: "Pause"))
                } icon: {
                    Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { showingEyeRestSession = true } label: {
                Label("Eye rest now", systemImage: "eye").frame(maxWidth: .infinity)
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
        if model.isPaused { return String(localized: "Reminders are paused") }
        guard let reminder = model.nextReminder else { return String(localized: "Enable a reminder to begin") }
        return "\(reminder.kind.title) · \(reminder.nextFireDate?.eyeRestTime ?? "")"
    }

    private func countdownText(at date: Date) -> String {
        if model.isPaused { return String(localized: "Paused") }
        guard !model.enabledReminders.isEmpty else { return "--:--:--" }
        return model.countdownText(to: model.nextDate, now: date)
    }
}
