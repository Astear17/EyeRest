import SwiftUI
import UIKit

struct EyeRestSessionView: View {
    private static let duration: TimeInterval = 20
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Binding var isPresented: Bool
    @State private var endDate: Date
    @State private var completed = false
    @State private var previousIdleTimerDisabled = false
    @State private var finishTask: Task<Void, Never>?

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _endDate = State(initialValue: Date.now.addingTimeInterval(Self.duration))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(completed ? String(localized: "Rest complete") : String(localized: "Look at something about 20 feet (6 m) away."))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let remaining = secondsRemaining(at: context.date)
                    ZStack {
                        Circle().stroke(.secondary.opacity(0.2), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: progress(at: context.date))
                            .stroke(.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: completed ? "checkmark" : "eye")
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    }
                    .frame(width: 190, height: 190)
                    .accessibilityLabel("Eye rest")
                    .accessibilityValue(completed ? String(localized: "Rest complete") : String(localized: "\(remaining) seconds remaining"))
                    .onChange(of: remaining) { _, value in
                        if value == 0 { finish() }
                    }
                    if !completed {
                        Text("\(remaining) seconds remaining")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                if !completed {
                    Button("Cancel", role: .cancel) { isPresented = false }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding(32)
            .navigationTitle("Eye rest")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.success, trigger: completed)
        .onAppear {
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            finishTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && !completed { isPresented = false }
        }
    }

    private func secondsRemaining(at date: Date) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(date))))
    }

    private func progress(at date: Date) -> Double {
        min(1, max(0, endDate.timeIntervalSince(date) / Self.duration))
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        model.complete(.eyeRest)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Rest complete"))
        finishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            isPresented = false
        }
    }
}
