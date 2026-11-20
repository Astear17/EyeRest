import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var completions: [Completion]
    @Published var now = Date.now
    @Published var showPermissionAlert = false
    private let persistence = PersistenceService()
    private let notifications = NotificationService.shared
    private var tick: Timer?
    init() { preferences = persistence.loadPreferences(); completions = persistence.loadCompletions(); startClock(); NotificationCenter.default.addObserver(forName: .eyeRestNotificationAction, object: nil, queue: .main) { [weak self] note in Task { @MainActor in self?.handle(notification: note) } } }
    deinit { tick?.invalidate() }
    var enabledReminders: [ReminderConfiguration] { preferences.reminders.filter(\.isEnabled) }
    var nextReminder: ReminderConfiguration? { guard !preferences.isPaused else { return nil }; return enabledReminders.compactMap { item in item.nextFireDate.map { (item, $0) } }.min { $0.1 < $1.1 }?.0 }
    var nextDate: Date? { nextReminder?.nextFireDate }
    var todayCount: Int { completions.filter { Calendar.current.isDateInToday($0.completedAt) }.count }
    func countdownText(to date: Date?) -> String { guard let date else { return "Paused" }; let seconds = max(0, Int(date.timeIntervalSince(now))); return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
    func launch() async { await notifications.refreshAuthorization(); if notifications.authorizationStatus == .notDetermined { _ = await notifications.requestAuthorization() }; await reconcile() }
    func reconcile() async {
        normalizeNextDates(); persistence.save(preferences)
        guard notifications.authorizationStatus == .authorized || notifications.authorizationStatus == .provisional || notifications.authorizationStatus == .ephemeral else { return }
        await notifications.reschedule(preferences: preferences)
    }
    func update(_ reminder: ReminderConfiguration) { guard let index = preferences.reminders.firstIndex(where: { $0.kind == reminder.kind }) else { return }; preferences.reminders[index] = reminder; saveAndReschedule() }
    func updatePreferences(_ change: (inout AppPreferences) -> Void) { change(&preferences); saveAndReschedule() }
    func togglePause() { preferences.isPaused.toggle(); saveAndReschedule() }
    func resetDefaults() { preferences = .makeDefault(); persistence.save(preferences); Task { await reconcile() } }
    func complete(_ kind: ReminderKind) { completions.append(Completion(kind: kind)); persistence.save(completions: completions); advance(kind); saveAndReschedule() }
    func startEyeRest() { complete(.eyeRest) }
    func snooze(_ kind: ReminderKind) { guard let reminder = preferences.reminders.first(where: { $0.kind == kind }) else { return }; Task { await notifications.scheduleSnooze(kind: kind, message: reminder.message, priority: preferences.priority) } }
    func openSettingsIfNeeded() { showPermissionAlert = true }
    private func advance(_ kind: ReminderKind) { guard let i = preferences.reminders.firstIndex(where: { $0.kind == kind }) else { return }; preferences.reminders[i].nextFireDate = Calendar.current.date(byAdding: .minute, value: preferences.reminders[i].intervalMinutes, to: .now) }
    private func normalizeNextDates(now: Date = .now) {
        for i in preferences.reminders.indices where preferences.reminders[i].isEnabled {
            var nextDate = preferences.reminders[i].nextFireDate
            if nextDate.map({ $0 <= now }) ?? true {
                nextDate = Calendar.current.date(byAdding: .minute, value: preferences.reminders[i].intervalMinutes, to: now)
            }
            if let nextDate {
                preferences.reminders[i].nextFireDate = preferences.quietHours.nextAllowedDate(nextDate)
            }
        }
    }
    private func saveAndReschedule() { persistence.save(preferences); Task { await reconcile() } }
    private func startClock() {
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.now = .now
                if let nextDate = self.nextDate, nextDate <= self.now {
                    self.normalizeNextDates(now: self.now)
                    self.persistence.save(self.preferences)
                }
            }
        }
    }
    private func handle(notification: Notification) { guard let kind = notification.userInfo?["kind"] as? ReminderKind, let action = notification.userInfo?["action"] as? String else { return }; if action == NotificationService.doneAction { complete(kind) } else if action == NotificationService.snoozeAction { snooze(kind) } }
}
