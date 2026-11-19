import SwiftUI
struct RootView: View {
    @State private var tab = 0
    var body: some View { TabView(selection: $tab) { HomeView(settingsTab: $tab).tabItem { Label("Today", systemImage: "sun.max") }.tag(0); RemindersView().tabItem { Label("Reminders", systemImage: "bell") }.tag(1); SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(2) } }
}
