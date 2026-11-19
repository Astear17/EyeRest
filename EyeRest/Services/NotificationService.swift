import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    static let categoryID = "EYEREST_REMINDER", snoozeAction = "SNOOZE_10", doneAction = "MARK_DONE"
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let center = UNUserNotificationCenter.current()
    override init() { super.init(); center.delegate = self; configureCategories(); Task { await refreshAuthorization() } }
    func configureCategories() {
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [
            UNNotificationAction(identifier: Self.doneAction, title: "Done", options: []),
            UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze 10 min", options: [])
        ], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }
    func refreshAuthorization() async { authorizationStatus = await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async -> Bool {
        do { let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]); await refreshAuthorization(); return granted } catch { await refreshAuthorization(); return false }
    }
    func cancelAll() async { center.removePendingNotificationRequests(withIdentifiers: await pendingIDs()) }
    func reschedule(preferences: AppPreferences, now: Date = .now) async {
        await cancelAll(); guard !preferences.isPaused else { return }
        // iOS allows at most 64 pending requests app-wide. 5 reminders × 8 occurrences = 40.
        for reminder in preferences.reminders where reminder.isEnabled { await scheduleBatch(reminder, preferences: preferences, from: now, count: 8) }
    }
    func scheduleBatch(_ reminder: ReminderConfiguration, preferences: AppPreferences, from start: Date, count: Int) async {
        var fire = reminder.nextFireDate ?? start
        if fire <= start { fire = Calendar.current.date(byAdding: .minute, value: reminder.intervalMinutes, to: start)! }
        for index in 0..<count {
            fire = nextAllowedDate(fire, quietHours: preferences.quietHours)
            let content = UNMutableNotificationContent()
            content.title = reminder.kind.title
            content.body = reminder.message
            content.sound = preferences.priority == .quiet ? nil : .default
            content.categoryIdentifier = Self.categoryID
            content.threadIdentifier = reminder.kind.rawValue
            content.userInfo = ["kind": reminder.kind.rawValue]
            content.interruptionLevel = preferences.priority.interruptionLevel
            let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fire)
            let request = UNNotificationRequest(identifier: "eyerest.\(reminder.kind.rawValue).\(Int(fire.timeIntervalSince1970)).\(index)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do { try await center.add(request) } catch { /* scheduling is reconciled on next activation */ }
            fire = Calendar.current.date(byAdding: .minute, value: reminder.intervalMinutes, to: fire)!
        }
    }
    func scheduleSnooze(kind: ReminderKind, message: String, priority: NotificationPriority) async {
        let content = UNMutableNotificationContent(); content.title = kind.title; content.body = message; content.sound = priority == .quiet ? nil : .default; content.categoryIdentifier = Self.categoryID; content.userInfo = ["kind": kind.rawValue]; content.interruptionLevel = priority.interruptionLevel
        let request = UNNotificationRequest(identifier: "eyerest.snooze.\(kind.rawValue).\(UUID().uuidString)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false))
        try? await center.add(request)
    }
    private func pendingIDs() async -> [String] { await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("eyerest.") } }
    private func nextAllowedDate(_ date: Date, quietHours: QuietHours) -> Date {
        guard quietHours.contains(date) else { return date }
        var day = Calendar.current.startOfDay(for: date)
        if quietHours.startMinutes > quietHours.endMinutes, Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date) >= quietHours.startMinutes { day = Calendar.current.date(byAdding: .day, value: 1, to: day)! }
        return Calendar.current.date(byAdding: .minute, value: quietHours.endMinutes, to: day)!
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let kind = ReminderKind(rawValue: response.notification.request.content.userInfo["kind"] as? String ?? "")
        guard let kind else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .eyeRestNotificationAction, object: nil, userInfo: ["action": response.actionIdentifier, "kind": kind])
        }
    }
}
extension Notification.Name { static let eyeRestNotificationAction = Notification.Name("EyeRestNotificationAction") }
