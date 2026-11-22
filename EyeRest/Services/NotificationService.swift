import Foundation
import Combine
import UserNotifications

struct MedicineNotificationResponse {
    let medicineID: UUID
    let scheduledAt: Date
    let snoozeMinutes: Int
    let action: String
    let requestIdentifier: String
}

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    static let quickCategoryID = "EYEREST_QUICK"
    static let guidedCategoryID = "EYEREST_GUIDED"
    static let snoozeAction = "SNOOZE"
    static let doneAction = "MARK_DONE"
    static let medicineCategoryID = "EYEREST_MEDICINE"
    static let medicineTakenAction = "MEDICINE_TAKEN"
    static let medicineSkipAction = "MEDICINE_SKIP"
    static let medicineSnoozeAction = "MEDICINE_SNOOZE"
    static let sharedThreadID = "eyerest.reminders"
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var timeSensitiveSetting: UNNotificationSetting = .notSupported
    private let center = UNUserNotificationCenter.current()
    private var bufferedActions: [(ReminderKind, String)] = []
    private var bufferedMedicineActions: [MedicineNotificationResponse] = []
    var actionHandler: ((ReminderKind, String) -> Void)? {
        didSet {
            guard let actionHandler else { return }
            let actions = bufferedActions
            bufferedActions.removeAll()
            actions.forEach { actionHandler($0.0, $0.1) }
        }
    }
    var medicineActionHandler: ((MedicineNotificationResponse) async -> Void)? {
        didSet {
            guard let medicineActionHandler else { return }
            let actions = bufferedMedicineActions
            bufferedMedicineActions.removeAll()
            Task {
                for action in actions { await medicineActionHandler(action) }
            }
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
        let medicine = [5, 10, 15].map { minutes in
            UNNotificationCategory(
                identifier: medicineCategoryID(snoozeMinutes: minutes),
                actions: [
                    UNNotificationAction(identifier: Self.medicineTakenAction, title: String(localized: "Taken"), options: []),
                    UNNotificationAction(identifier: Self.medicineSkipAction, title: String(localized: "Skip"), options: []),
                    UNNotificationAction(identifier: Self.medicineSnoozeAction, title: String(localized: "Snooze \(minutes) min"), options: [])
                ],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: "",
                categorySummaryFormat: summary,
                options: []
            )
        }
        center.setNotificationCategories(Set([quick, guided] + medicine))
    }
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        timeSensitiveSetting = settings.timeSensitiveSetting
    }
    func requestAuthorization() async -> Bool {
        do { let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive]); await refreshAuthorization(); return granted } catch { await refreshAuthorization(); return false }
    }
    func reschedule(preferences: AppPreferences, medicineData: MedicineData, now: Date = .now) async -> CombinedNotificationPlan {
        configureCategories(snoozeMinutes: preferences.snoozeMinutes)
        let planned = NotificationPlanner.combinedPlan(preferences: preferences, medicineData: medicineData, now: now)
        let pending = await center.pendingNotificationRequests()
        let diff = NotificationPlanner.reconciliationDiff(pendingIDs: pending.map(\.identifier), plan: planned)
        center.removePendingNotificationRequests(withIdentifiers: diff.allStaleIDs)

        if preferences.pausedUntil.map({ $0 > now }) == true {
            await removeAllSnoozes()
        } else {
            let enabledKinds = Set(preferences.reminders.filter(\.isEnabled).map(\.kind))
            for kind in ReminderKind.allCases where !enabledKinds.contains(kind) {
                await removeSnooze(kind: kind)
            }
        }

        for item in planned.wellness {
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
        for item in planned.medicine {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.categoryIdentifier = medicineCategoryID(snoozeMinutes: item.snoozeMinutes)
            content.threadIdentifier = Self.sharedThreadID
            content.summaryArgument = item.title
            content.userInfo = medicineUserInfo(
                medicineID: item.medicineID,
                scheduledAt: item.scheduledAt,
                snoozeMinutes: item.snoozeMinutes
            )
            content.interruptionLevel = medicineInterruptionLevel()
            let request = UNNotificationRequest(
                identifier: item.id,
                content: content,
                trigger: calendarTrigger(for: item.scheduledAt)
            )
            do { try await center.add(request) } catch { /* scheduling is reconciled on next activation */ }
        }
        return planned
    }
    func scheduleSnooze(kind: ReminderKind, message: String, fireDate: Date, priority: NotificationPriority) async {
        let content = UNMutableNotificationContent(); content.title = kind.title; content.body = message; content.sound = priority == .quiet ? nil : .default; content.categoryIdentifier = categoryID(for: kind); content.threadIdentifier = Self.sharedThreadID; content.summaryArgument = kind.title; content.userInfo = ["kind": kind.rawValue]; content.interruptionLevel = interruptionLevel(for: priority)
        let calendar = Calendar.autoupdatingCurrent
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        components.timeZone = calendar.timeZone
        let request = UNNotificationRequest(identifier: snoozeID(for: kind), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try? await center.add(request)
    }
    func removeSnooze(kind: ReminderKind) async {
        center.removePendingNotificationRequests(withIdentifiers: [snoozeID(for: kind)])
    }
    func removeAllSnoozes() async {
        let wellnessIDs = Set(ReminderKind.allCases.map { snoozeID(for: $0) })
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { wellnessIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    func scheduleMedicineSnooze(
        medicineID: UUID,
        name: String,
        scheduledAt: Date,
        fireDate: Date,
        snoozeMinutes: Int,
        hideName: Bool
    ) async {
        let content = UNMutableNotificationContent()
        content.title = hideName ? String(localized: "Medicine reminder") : name
        content.body = String(localized: "Time for your medicine")
        content.sound = .default
        content.categoryIdentifier = medicineCategoryID(snoozeMinutes: snoozeMinutes)
        content.threadIdentifier = Self.sharedThreadID
        content.summaryArgument = content.title
        content.userInfo = medicineUserInfo(medicineID: medicineID, scheduledAt: scheduledAt, snoozeMinutes: snoozeMinutes)
        content.interruptionLevel = medicineInterruptionLevel()
        let request = UNNotificationRequest(
            identifier: NotificationPlanner.medicineSnoozeIdentifier(medicineID: medicineID, scheduledAt: scheduledAt),
            content: content,
            trigger: calendarTrigger(for: fireDate)
        )
        try? await center.add(request)
    }
    func clearMedicineDose(medicineID: UUID, scheduledAt: Date, deliveredRequestID: String? = nil) {
        let normalID = NotificationPlanner.medicineIdentifier(medicineID: medicineID, scheduledAt: scheduledAt)
        let snoozeID = NotificationPlanner.medicineSnoozeIdentifier(medicineID: medicineID, scheduledAt: scheduledAt)
        center.removePendingNotificationRequests(withIdentifiers: [normalID, snoozeID])
        center.removeDeliveredNotifications(withIdentifiers: [normalID, snoozeID] + [deliveredRequestID].compactMap { $0 })
    }
    private func snoozeID(for kind: ReminderKind) -> String { "eyerest.snooze.\(kind.rawValue)" }
    private func interruptionLevel(for priority: NotificationPriority) -> UNNotificationInterruptionLevel {
        priority == .timeSensitive && timeSensitiveSetting == .enabled ? .timeSensitive : .active
    }
    private func medicineInterruptionLevel() -> UNNotificationInterruptionLevel {
        timeSensitiveSetting == .enabled ? .timeSensitive : .active
    }
    private func medicineCategoryID(snoozeMinutes: Int) -> String {
        snoozeMinutes == 10 ? Self.medicineCategoryID : "\(Self.medicineCategoryID)_\(snoozeMinutes)"
    }
    private func medicineUserInfo(medicineID: UUID, scheduledAt: Date, snoozeMinutes: Int) -> [AnyHashable: Any] {
        [
            "medicineID": medicineID.uuidString,
            "scheduledAt": MedicineDoseIdentity(medicineID: medicineID, scheduledAt: scheduledAt).scheduledEpochSeconds,
            "snoozeMinutes": snoozeMinutes
        ]
    }
    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let calendar = Calendar.autoupdatingCurrent
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
    private func deliverMedicine(_ response: MedicineNotificationResponse) async {
        if let medicineActionHandler { await medicineActionHandler(response) }
        else { bufferedMedicineActions.append(response) }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .list, .sound] }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        if let rawID = info["medicineID"] as? String,
           let medicineID = UUID(uuidString: rawID),
           let scheduledEpoch = (info["scheduledAt"] as? NSNumber)?.int64Value,
           let snoozeMinutes = (info["snoozeMinutes"] as? NSNumber)?.intValue {
            await self.deliverMedicine(MedicineNotificationResponse(
                medicineID: medicineID,
                scheduledAt: Date(timeIntervalSince1970: TimeInterval(scheduledEpoch)),
                snoozeMinutes: snoozeMinutes,
                action: response.actionIdentifier,
                requestIdentifier: response.notification.request.identifier
            ))
            return
        }
        let kind = ReminderKind(rawValue: response.notification.request.content.userInfo["kind"] as? String ?? "")
        guard let kind else { return }
        await MainActor.run {
            self.deliver(kind: kind, action: response.actionIdentifier)
        }
    }
}
