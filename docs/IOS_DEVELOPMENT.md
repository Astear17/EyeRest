# EyeRest iOS development notes

## Target and architecture

- **Platform:** iPhone XS and newer, iOS 17+
- **UI:** SwiftUI, native SF Symbols, Dynamic Type and VoiceOver support
- **Bundle identifier:** `com.astear17.eyerest`
- **Architecture:** feature-oriented SwiftUI modules with `Models`, `Services`, `ViewModels`, `Views`, and `Utilities` groups.

Keep domain models (`Reminder`, `ReminderConfiguration`, `ReminderEvent`) independent of UI. A `ReminderScheduler` service should own `UNUserNotificationCenter` interaction; a local persistence service should store settings and completion history. View models derive countdown UI from absolute next-fire dates rather than assuming a continuously running timer.

## Notifications and offline operation

EyeRest should schedule local notifications for eye relaxation, hydration, blinking, posture, and movement independently. Each has enabled state, interval, custom text, next scheduled time, and snooze.

Request notification authorization when the user enables reminders. Use `UNNotificationInterruptionLevel.timeSensitive` as the intended default only when permission and the user’s iOS settings permit it; gracefully fall back to `.active`. “Quiet” should be a standard local notification without sound. Never use Critical Alerts.

iOS limits the number of pending local notifications. Schedule a bounded batch per reminder, use stable identifiers, cancel/reconcile affected identifiers after a settings change, and replenish the batch when the app becomes active. Evaluate quiet hours before generating each trigger. Store and calculate with absolute dates to tolerate timezone and daylight-saving changes.

No remote notifications, analytics, accounts, cloud storage, or network API are required. Settings and history remain on-device. iOS does not guarantee background execution, so scheduling must be correct even if the app is terminated.

## macOS build requirements

1. macOS with a current Xcode version capable of targeting iOS 17.
2. An Apple ID / developer team for device installation and signing.
3. A physical iPhone XS or newer for notification and device validation.

Open the `.xcodeproj` or `.xcworkspace`, select an iOS 17+ deployment target, assign the bundle identifier and signing team, then build/run on device. Validate permission-denied paths, each reminder’s reschedule/cancel behavior, quiet hours, snooze, app restart persistence, timezone changes, and notification action handling.

## Unsigned IPA reality

An archive made with `CODE_SIGNING_ALLOWED=NO` is useful for compilation or inspection, but it is not an installable iPhone app on its own. iOS requires a valid code signature for installation. A development-signed build from Xcode, AltStore, Sideloadly, or an authorized distribution channel is necessary to place an app on a normal device. Do not report an IPA as installable until the archive/export and target-device installation both succeed.
