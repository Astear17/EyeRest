import SwiftUI
struct HomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @Binding var settingsTab: Int
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 6) { Text("Next reminder").font(.subheadline).foregroundStyle(.secondary); Text(model.countdownText(to: model.nextDate)).font(.system(size: 54, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.65).accessibilityLabel("Countdown \(model.countdownText(to: model.nextDate))"); Text(model.nextReminder.map { "\($0.kind.title) · \($0.nextFireDate?.eyeRestTime ?? "")" } ?? "Enable a reminder to begin").font(.headline).foregroundStyle(.secondary) }.padding(.top, 12)
        HStack(spacing: 12) { Button { model.togglePause() } label: { Label(model.preferences.isPaused ? "Resume" : "Pause", systemImage: model.preferences.isPaused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent); Button { model.startEyeRest() } label: { Label("Eye rest now", systemImage: "eye").frame(maxWidth: .infinity) }.buttonStyle(.bordered) }.controlSize(.large)
        Divider()
        HStack { Label("Today", systemImage: "checkmark.circle"); Spacer(); Text("\(model.todayCount) completed").fontWeight(.semibold) }.font(.headline)
        Text("Your reminders are scheduled privately on this iPhone. EyeRest does not collect or send any data.").font(.footnote).foregroundStyle(.secondary)
    }.padding() }.navigationTitle("EyeRest").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settingsTab = 2 } label: { Image(systemName: "gearshape") }.accessibilityLabel("Open settings") } } } }
}
