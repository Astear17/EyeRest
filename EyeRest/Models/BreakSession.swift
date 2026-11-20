import Foundation

enum BreakSessionState: Equatable {
    case idle
    case running
    case paused
    case completed
    case cancelled
}

struct BreakSession: Equatable {
    let duration: TimeInterval
    let stepDurations: [TimeInterval]
    private(set) var state: BreakSessionState = .idle
    private(set) var endDate: Date?
    private(set) var pausedRemaining: TimeInterval?
    private(set) var didReportCompletion = false

    init(duration: TimeInterval, stepDurations: [TimeInterval] = []) {
        self.duration = max(0, duration)
        let valid = stepDurations.map { max(0, $0) }
        self.stepDurations = valid.isEmpty ? [max(0, duration)] : valid
    }

    mutating func start(at date: Date = .now) {
        guard state == .idle else { return }
        endDate = date.addingTimeInterval(duration)
        pausedRemaining = nil
        state = duration == 0 ? .completed : .running
    }

    mutating func pause(at date: Date = .now) {
        guard state == .running else { return }
        pausedRemaining = remaining(at: date)
        endDate = nil
        state = .paused
    }

    mutating func resume(at date: Date = .now) {
        guard state == .paused, let pausedRemaining else { return }
        endDate = date.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
        state = pausedRemaining == 0 ? .completed : .running
    }

    mutating func cancel() {
        guard state == .running || state == .paused else { return }
        endDate = nil
        pausedRemaining = nil
        state = .cancelled
    }

    @discardableResult
    mutating func update(at date: Date = .now) -> Bool {
        guard state == .running, remaining(at: date) == 0 else { return false }
        state = .completed
        endDate = nil
        guard !didReportCompletion else { return false }
        didReportCompletion = true
        return true
    }

    func remaining(at date: Date = .now) -> TimeInterval {
        switch state {
        case .idle: return duration
        case .running: return max(0, endDate?.timeIntervalSince(date) ?? 0)
        case .paused: return max(0, pausedRemaining ?? 0)
        case .completed, .cancelled: return 0
        }
    }

    func progress(at date: Date = .now) -> Double {
        guard duration > 0 else { return state == .idle ? 0 : 1 }
        return min(1, max(0, 1 - remaining(at: date) / duration))
    }

    func currentStepIndex(at date: Date = .now) -> Int {
        let elapsed = max(0, duration - remaining(at: date))
        var boundary: TimeInterval = 0
        for (index, step) in stepDurations.enumerated() {
            boundary += step
            if elapsed < boundary { return index }
        }
        return max(0, stepDurations.count - 1)
    }
}
