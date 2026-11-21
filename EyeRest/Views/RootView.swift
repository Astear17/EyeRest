import SwiftUI
struct RootView: View {
    @EnvironmentObject private var model: AppViewModel
    @State private var tab = 0
    @State private var selectedActivity: BreakActivity?

    var body: some View {
        TabView(selection: $tab) {
            HomeView(settingsTab: $tab).tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
            RemindersView().tabItem { Label("Reminders", systemImage: "bell") }.tag(1)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
            ActivityView().tabItem { Label("Activity", systemImage: "chart.bar") }.tag(3)
        }
        .onAppear { presentRequestedBreak() }
        .onChange(of: model.requestedBreakActivity) { _, _ in presentRequestedBreak() }
        .sheet(item: $selectedActivity) { activity in
            EyeRestSessionView(activity: activity)
                .environmentObject(model)
                .interactiveDismissDisabled(true)
        }
    }

    private func presentRequestedBreak() {
        guard let activity = model.requestedBreakActivity else { return }
        tab = 0
        selectedActivity = activity
        model.consumeRequestedBreak()
    }
}
