import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var model: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false

    let isReplay: Bool

    init(isReplay: Bool = false) {
        self.isReplay = isReplay
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                brandMark
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Give your eyes a moment.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Gentle reminders and guided breaks, right on your schedule.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 22) {
                    benefit(
                        symbol: "bell.badge",
                        title: "Five gentle reminders on your own schedule"
                    )
                    benefit(
                        symbol: "timer",
                        title: "Guided breaks with a calm countdown"
                    )
                    benefit(
                        symbol: "hand.raised",
                        title: "Private and offline",
                        detail: "No account, no ads, no tracking, and your data stays on this iPhone."
                    )
                }

                Text("EyeRest will ask for notification permission. You can change this later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 112)
        }
        .background(background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button(isReplay ? "Done" : "Get started") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(isWorking)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var background: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 16 / 255, green: 23 / 255, blue: 25 / 255),
                        Color(red: 23 / 255, green: 33 / 255, blue: 29 / 255)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(red: 245 / 255, green: 246 / 255, blue: 241 / 255)
            }
        }
    }

    private var brandMark: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor, lineWidth: 5)
            GeometryReader { geometry in
                Path { path in
                    let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    path.move(to: centre)
                    path.addLine(to: CGPoint(x: centre.x, y: geometry.size.height * 0.18))
                    path.move(to: centre)
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.72, y: geometry.size.height * 0.68))
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
        }
        .frame(width: 64, height: 64)
    }

    private func benefit(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey? = nil) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        if isReplay {
            dismiss()
            return
        }
        isWorking = true
        Task {
            await model.completeWelcome()
            isWorking = false
        }
    }
}
