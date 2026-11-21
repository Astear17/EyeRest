import SwiftUI
import UIKit

struct EyeRestSessionView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 190

    let activity: BreakActivity
    @State private var session: BreakSession
    @State private var currentStepIndex = 0
    @State private var stepFeedback = 0
    @State private var completionFeedback = 0
    @State private var completionPulse = false
    @State private var previousIdleTimerDisabled = false
    @State private var finishTask: Task<Void, Never>?

    init(activity: BreakActivity) {
        self.activity = activity
        _session = State(initialValue: BreakSession(
            duration: activity.duration,
            stepDurations: activity.stepDurations
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    timeline
                    if let safetyNote = activity.safetyNote {
                        Label(safetyNote, systemImage: "exclamationmark.triangle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationTitle(activity.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { controls }
        }
        .sensoryFeedback(.selection, trigger: stepFeedback) { _, _ in model.preferences.hapticsEnabled }
        .sensoryFeedback(.success, trigger: completionFeedback) { _, _ in model.preferences.hapticsEnabled }
        .onAppear {
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            session.start()
        }
        .onDisappear {
            finishTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause() }
        }
    }

    @ViewBuilder
    private var timeline: some View {
        if reduceMotion {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                sessionContent(at: context.date)
            }
        } else {
            TimelineView(.animation(paused: session.state != .running)) { context in
                sessionContent(at: context.date)
            }
        }
    }

    private func sessionContent(at date: Date) -> some View {
        let remaining = Int(ceil(session.remaining(at: date)))
        let stepIndex = session.currentStepIndex(at: date)
        let step = activity.steps[stepIndex]
        let completed = session.state == .completed
        let diameter = min(ringSize, 240)

        return VStack(spacing: 24) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: session.progress(at: date))
                    .stroke(.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(session.state == .paused ? 0.45 : 1)
                Image(systemName: completed ? "checkmark" : activity.symbol)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .scaleEffect(completed && completionPulse ? 1.18 : 1)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(activity.title)
            .accessibilityValue(completed ? String(localized: "Break complete") : String(localized: "\(remaining) seconds remaining"))

            VStack(spacing: 10) {
                Text(completed ? String(localized: "Break complete") : step.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if !completed {
                    Text(step.instruction)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\(remaining) seconds remaining")
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            .id(completed ? "complete" : "step-\(stepIndex)")
            .transition(stepTransition)
            .accessibilityElement(children: .combine)
            .onChange(of: remaining) { _, value in
                updateSession(at: date, remaining: value, stepIndex: stepIndex)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 12) {
            switch session.state {
            case .running:
                Button("Pause") { session.pause() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .paused:
                Button("Resume") { session.resume() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .completed:
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            case .idle, .cancelled:
                EmptyView()
            }
            if session.state == .running || session.state == .paused {
                Button("End", role: .cancel) {
                    session.cancel()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom))
    }

    private func updateSession(at date: Date, remaining: Int, stepIndex: Int) {
        if stepIndex != currentStepIndex {
            currentStepIndex = stepIndex
            stepFeedback += 1
        }
        guard remaining == 0, session.update(at: date) else { return }
        model.complete(
            activity.reminderKind,
            source: .guided,
            durationSeconds: Int(activity.duration),
            activityID: activity.id
        )
        completionFeedback += 1
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Break complete"))
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { completionPulse = true }
        finishTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { completionPulse = false }
        }
    }
}
