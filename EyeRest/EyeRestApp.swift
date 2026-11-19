import SwiftUI
@main
struct EyeRestApp: App {
    @StateObject private var model = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(colorScheme)
                .task {
                    await model.launch()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await model.launch()
                        }
                    }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch model.preferences.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
