import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    static let quickCategoryID = "EYEREST_QUICK"
    static let guidedCategoryID = "EYEREST_GUIDED"
    static let snoozeAction = "SNOOZE"
    static let doneAction = "MARK_DONE"
    static let sharedThreadID = "eyerest.reminders"
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var timeSensitiveSetting: UNNotificationSetting = .notSupported
    private let center = UNUserNotificationCenter.current()
    private var bufferedActions: [(ReminderKind, String)] = []
    var actionHandler: ((ReminderKind, String) -> Void)? {
        didSet {
            guard let actionHandler else { return }
            let actions = bufferedActions
            bufferedActions.removeAll()
            actions.forEach { actionHandler($0.0, $0.1) }
        }
    }
    override init() { super.init(); center.delegate = self; configureCategories(); Task { await refreshAuthorization() } }
    func configureCategories(snoozeMinutes: Int? = nil) {
        let snooze = snoozeMinutes.map {
            UNNotificationAction(identifier: Self.snoozeAction, title: String(localized: "Snooze \($0) min"), options: [])
        }
        let quickActions = [
            UNNotificationAction(identifier: Self.doneAction, title: String(localized: "Done"), options: [])
        ] + [snooze].compactMap { $0 }
        let guidedActions = [snooze].compactMap { $0 }
        let summary = String(localized: "%u more reminders")
        let quick = UNNotificationCategory(
            identifier: Self.quickCategoryID,
            actions: quickActions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            categorySummaryFormat: summary,
            options: []
        )
        let guided = UNNotificationCategory(
            identifier: Self.guidedCategoryID,
            actions: guidedActions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            categorySummaryFormat: summary,
            options: []
        )
        center.setNotificationCategories([quick, guided])
    }
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        timeSensitiveSetting = settings.timeSensitiveSetting
    }
    func requestAuthorization() async -> Bool {
        do { let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]); await refreshAuthorization(); return granted } catch { await refreshAuthorization(); return false }
    }
    func reschedule(preferences: AppPreferences, now: Date = .now) async -> [PlannedNotification] {
        configureCategories(snoozeMinutes: preferences.snoozeMinutes)
        let planned = NotificationPlanner.plan(preferences: preferences, now: now)
        let plannedIDs = Set(planned.map(\.id))
        let pending = await center.pendingNotificationRequests()
        let normalIDs = pending.map(\.identifier).filter { $0.hasPrefix("eyerest.") && !$0.hasPrefix("eyerest.snooze.") }
        center.removePendingNotificationRequests(withIdentifiers: normalIDs.filter { !plannedIDs.contains($0) })

        if preferences.pausedUntil.map({ $0 > now }) == true {
            await removeAllSnoozes()
        } else {
            let enabledKinds = Set(preferences.reminders.filter(\.isEnabled).map(\.kind))
            for kind in ReminderKind.allCases where !enabledKinds.contains(kind) {
                await removeSnooze(kind: kind)
            }
        }

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = preferences.priority == .quiet ? nil : .default
            content.categoryIdentifier = categoryID(for: item.kind)
            content.threadIdentifier = Self.sharedThreadID
            content.summaryArgument = item.title
            content.userInfo = ["kind": item.kind.rawValue]
            content.interruptionLevel = interruptionLevel(for: preferences.priority)
            let calendar = Calendar.autoupdatingCurrent
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do { try await center.add(request) } catch { /* scheduling is reconciled on next activation */ }
        }
        return planned
    }
    func scheduleSnooze(kind: ReminderKind, message: String, minutes: Int, priority: NotificationPriority) async {
        let content = UNMutableNotificationContent(); content.title = kind.title; content.body = message; content.sound = priority == .quiet ? nil : .default; content.categoryIdentifier = categoryID(for: kind); content.threadIdentifier = Self.sharedThreadID; content.summaryArgument = kind.title; content.userInfo = ["kind": kind.rawValue]; content.interruptionLevel = interruptionLevel(for: priority)
        let request = UNNotificationRequest(identifier: snoozeID(for: kind), content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false))
        try? await center.add(request)
    }
    func removeSnooze(kind: ReminderKind) async {
        center.removePendingNotificationRequests(withIdentifiers: [snoozeID(for: kind)])
    }
    func removeAllSnoozes() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("eyerest.snooze.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    private func snoozeID(for kind: ReminderKind) -> String { "eyerest.snooze.\(kind.rawValue)" }
    private func interruptionLevel(for priority: NotificationPriority) -> UNNotificationInterruptionLevel {
        priority == .timeSensitive && timeSensitiveSetting == .enabled ? .timeSensitive : .active
    }
    private func categoryID(for kind: ReminderKind) -> String {
        switch kind {
        case .hydration, .blinking: Self.quickCategoryID
        case .eyeRest, .posture, .movement: Self.guidedCategoryID
        }
    }
    private func deliver(kind: ReminderKind, action: String) {
        if let actionHandler { actionHandler(kind, action) } else { bufferedActions.append((kind, action)) }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let kind = ReminderKind(rawValue: response.notification.request.content.userInfo["kind"] as? String ?? "")
        guard let kind else { return }
        await MainActor.run {
            self.deliver(kind: kind, action: response.actionIdentifier)
        }
    }
}
