import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var completions: [Completion]
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isTimeSensitiveAvailable = false
    @Published private(set) var queuedUntil: Date?
    @Published var showPermissionAlert = false
    private let persistence = PersistenceService()
    private let notifications = NotificationService.shared
    private var tick: Timer?
    private var observationTokens: [NSObjectProtocol] = []
    private var reconcileTask: Task<Void, Never>?
    private var reconcilePending = false

    init() {
        preferences = persistence.loadPreferences()
        completions = persistence.loadCompletions()
        notifications.actionHandler = { [weak self] kind, action in self?.handle(kind: kind, action: action) }
        observeSystemChanges()
        startClock()
    }

    deinit {
        tick?.invalidate()
        observationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    var enabledReminders: [ReminderConfiguration] { preferences.reminders.filter(\.isEnabled) }
    var nextReminder: ReminderConfiguration? { guard !preferences.isPaused else { return nil }; return enabledReminders.compactMap { item in item.nextFireDate.map { (item, $0) } }.min { $0.1 < $1.1 }?.0 }
    var nextDate: Date? { nextReminder?.nextFireDate }
    var todayCount: Int { completions.filter { Calendar.autoupdatingCurrent.isDateInToday($0.completedAt) }.count }
    var canScheduleNotifications: Bool { authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral }

    func countdownText(to date: Date?, now: Date) -> String {
        guard let date else { return "--:--:--" }
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    func launch() async {
        await notifications.refreshAuthorization()
        if notifications.authorizationStatus == .notDetermined { _ = await notifications.requestAuthorization() }
        await reconcile()
    }

    func requestNotificationAuthorization() async {
        let granted = await notifications.requestAuthorization()
        await reconcile()
        if !granted { showPermissionAlert = true }
    }

    func reconcile() async {
        reconcilePending = true
        if let running = reconcileTask {
            await running.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.reconcilePending {
                self.reconcilePending = false
                await self.performReconcile()
            }
            self.reconcileTask = nil
        }
        reconcileTask = task
        await task.value
    }

    func update(kind: ReminderKind, isEnabled: Bool, intervalMinutes: Int, customMessage: String?) {
        guard let index = preferences.reminders.firstIndex(where: { $0.kind == kind }) else { return }
        let wasEnabled = preferences.reminders[index].isEnabled
        let previousInterval = preferences.reminders[index].intervalMinutes
        preferences.reminders[index].isEnabled = isEnabled
        preferences.reminders[index].intervalMinutes = min(max(intervalMinutes, 5), 360)
        preferences.reminders[index].customMessage = ReminderConfiguration.normalizedCustomMessage(customMessage)
        if previousInterval != intervalMinutes || (!wasEnabled && isEnabled) {
            preferences.reminders[index].nextFireDate = adjustedDate(for: kind, intervalMinutes: preferences.reminders[index].intervalMinutes)
        }
        saveAndReschedule()
    }

    func updatePreferences(_ change: (inout AppPreferences) -> Void) { change(&preferences); saveAndReschedule() }
    func togglePause() { preferences.isPaused.toggle(); saveAndReschedule() }

    func resetDefaults() {
        preferences.reminders = AppPreferences.makeDefault().reminders
        saveAndReschedule()
    }

    func complete(_ kind: ReminderKind) {
        completions.append(Completion(kind: kind))
        persistence.save(completions: completions)
        advance(kind)
        persistence.save(preferences)
        Task {
            await notifications.removeSnooze(kind: kind)
            await reconcile()
        }
    }

    func snooze(_ kind: ReminderKind) {
        guard let reminder = preferences.reminders.first(where: { $0.kind == kind }) else { return }
        Task { await notifications.scheduleSnooze(kind: kind, message: reminder.message, priority: preferences.priority) }
    }

    func openSettingsIfNeeded() { showPermissionAlert = true }

    private func performReconcile() async {
        await notifications.refreshAuthorization()
        authorizationStatus = notifications.authorizationStatus
        isTimeSensitiveAvailable = notifications.timeSensitiveSetting == .enabled
        normalizeNextDates()
        persistence.save(preferences)
        guard canScheduleNotifications else {
            queuedUntil = nil
            return
        }
        let planned = await notifications.reschedule(preferences: preferences)
        let lastDates = enabledReminders.compactMap { reminder in
            planned.last(where: { $0.kind == reminder.kind })?.fireDate
        }
        queuedUntil = lastDates.min()
    }

    private func adjustedDate(for kind: ReminderKind, intervalMinutes: Int, now: Date = .now) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let proposed = calendar.date(byAdding: .minute, value: intervalMinutes, to: now) ?? now
        return preferences.quietHours.nextAllowedDate(proposed, stagger: kind.quietHoursStagger, calendar: calendar)
    }

    private func advance(_ kind: ReminderKind) {
        guard let index = preferences.reminders.firstIndex(where: { $0.kind == kind }) else { return }
        preferences.reminders[index].nextFireDate = adjustedDate(for: kind, intervalMinutes: preferences.reminders[index].intervalMinutes)
    }

    private func normalizeNextDates(now: Date = .now) {
        let calendar = Calendar.autoupdatingCurrent
        for index in preferences.reminders.indices where preferences.reminders[index].isEnabled {
            var nextDate = preferences.reminders[index].nextFireDate
            if nextDate.map({ $0 <= now }) ?? true {
                nextDate = calendar.date(byAdding: .minute, value: preferences.reminders[index].intervalMinutes, to: now)
            }
            if let nextDate {
                preferences.reminders[index].nextFireDate = preferences.quietHours.nextAllowedDate(nextDate, stagger: preferences.reminders[index].kind.quietHoursStagger, calendar: calendar)
            }
        }
    }

    private func saveAndReschedule() {
        persistence.save(preferences)
        Task { await reconcile() }
    }

    private func startClock() {
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let nextDate = self.nextDate, nextDate <= Date.now else { return }
                await self.reconcile()
            }
        }
    }

    private func observeSystemChanges() {
        let center = NotificationCenter.default
        observationTokens.append(center.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.reconcile() }
        })
        observationTokens.append(center.addObserver(forName: Notification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.reconcile() }
        })
        observationTokens.append(center.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.notifications.configureCategories()
                await self?.reconcile()
            }
        })
    }

    private func handle(kind: ReminderKind, action: String) {
        if action == NotificationService.doneAction { complete(kind) }
        else if action == NotificationService.snoozeAction { snooze(kind) }
    }
}
