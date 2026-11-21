import Foundation

struct BreakActivityStep: Equatable {
    let duration: TimeInterval
    let title: String
    let instruction: String
}

struct BreakActivity: Identifiable, Equatable {
    let id: String
    let reminderKind: ReminderKind
    let title: String
    let symbol: String
    let steps: [BreakActivityStep]
    let safetyNote: String?

    var duration: TimeInterval { steps.reduce(0) { $0 + $1.duration } }
    var stepDurations: [TimeInterval] { steps.map(\.duration) }

    static var all: [BreakActivity] {
        [eyeRest, eyeRelaxation, postureCheck, movement]
    }

    static var eyeRest: BreakActivity {
        BreakActivity(
            id: "eye-rest",
            reminderKind: .eyeRest,
            title: String(localized: "Eye rest"),
            symbol: "eye",
            steps: [BreakActivityStep(
                duration: 20,
                title: String(localized: "Look into the distance"),
                instruction: String(localized: "Look at something about 20 feet (6 m) away.")
            )],
            safetyNote: nil
        )
    }

    static var eyeRelaxation: BreakActivity {
        BreakActivity(
            id: "eye-relaxation",
            reminderKind: .eyeRest,
            title: String(localized: "Eye relaxation"),
            symbol: "eye.circle",
            steps: [
                BreakActivityStep(duration: 20, title: String(localized: "Look far"), instruction: String(localized: "Look at something far away.")),
                BreakActivityStep(duration: 20, title: String(localized: "Rest your eyes"), instruction: String(localized: "Close your eyes or gently cover them with your palms.")),
                BreakActivityStep(duration: 20, title: String(localized: "Shift focus"), instruction: String(localized: "Focus on something nearby, then something far away."))
            ],
            safetyNote: nil
        )
    }

    static var postureCheck: BreakActivity {
        BreakActivity(
            id: "posture-check",
            reminderKind: .posture,
            title: String(localized: "Posture check"),
            symbol: "figure.stand",
            steps: [
                BreakActivityStep(duration: 10, title: String(localized: "Sit tall"), instruction: String(localized: "Place both feet flat and sit tall.")),
                BreakActivityStep(duration: 10, title: String(localized: "Roll shoulders"), instruction: String(localized: "Roll your shoulders back and down.")),
                BreakActivityStep(duration: 10, title: String(localized: "Release tension"), instruction: String(localized: "Unclench your jaw and relax your hands."))
            ],
            safetyNote: nil
        )
    }

    static var movement: BreakActivity {
        BreakActivity(
            id: "stand-and-move",
            reminderKind: .movement,
            title: String(localized: "Stand up and move"),
            symbol: "figure.walk",
            steps: [
                BreakActivityStep(duration: 10, title: String(localized: "Stand up"), instruction: String(localized: "Stand up at a comfortable pace.")),
                BreakActivityStep(duration: 30, title: String(localized: "Neck and shoulders"), instruction: String(localized: "Gently roll your neck and shoulders.")),
                BreakActivityStep(duration: 30, title: String(localized: "Arms and wrists"), instruction: String(localized: "Stretch your arms and wrists gently.")),
                BreakActivityStep(duration: 40, title: String(localized: "Walk in place"), instruction: String(localized: "Walk in place at a comfortable pace.")),
                BreakActivityStep(duration: 10, title: String(localized: "Sit down"), instruction: String(localized: "Sit down slowly when you are ready."))
            ],
            safetyNote: String(localized: "Stop if anything hurts.")
        )
    }

    static func defaultActivity(for kind: ReminderKind) -> BreakActivity? {
        switch kind {
        case .eyeRest: eyeRest
        case .posture: postureCheck
        case .movement: movement
        case .hydration, .blinking: nil
        }
    }
}
