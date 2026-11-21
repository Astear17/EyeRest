# EyeRest iOS development notes

## Target and architecture

- Platform: iPhone, iOS 17.0+, Swift 5.9 language mode
- UI: SwiftUI with Dynamic Type and VoiceOver support
- Bundle identifier: `com.astear17.eyerest`
- Dependencies: Apple frameworks only; no network, accounts, analytics, or third-party packages

`Reminder.swift` owns reminder defaults, persistence models, quiet-hours policy, and stable per-kind staggering. `NotificationPlanner` is a Foundation-only pure planner. `NotificationService` owns `UNUserNotificationCenter`, authorization, request diffing, snoozes, categories, and action delivery. `AppViewModel` serializes reconciliation and owns persisted app state. Views mutate settings only through the view model.

## Notification planning

iOS permits at most 64 pending local notifications per app. EyeRest reserves six slots for snoozes and plans at most 58 normal requests. Every enabled reminder receives up to three guaranteed occurrences; remaining slots are filled by the earliest next occurrence across kinds. This prevents a short interval from starving a long interval while using a similar time horizon for every kind.

Normal request identifiers are `eyerest.<kind>.<epoch>`. Reconciliation removes obsolete normal identifiers and replaces the complete planned set so message and interruption-level changes take effect. Snoozes use one stable `eyerest.snooze.<kind>` identifier per kind and survive normal reconciliation. Pausing, disabling a kind, or marking that kind Done removes the applicable snooze.

All schedules use absolute dates and non-repeating triggers. The planner, displayed next date, and system request use `Calendar.autoupdatingCurrent`. Trigger components include the current time zone. Significant-time, time-zone, and locale changes cause a serialized rebuild. Quiet-hour end dates use calendar hour/minute construction for DST safety and are staggered by three minutes in stable reminder-kind order.

The queue is finite because iOS provides no indefinite background scheduler. The Home screen displays the shortest queued horizon; open EyeRest periodically to replenish it.

## Persistence and localization

Preferences and completion history remain JSON data under `EyeRest.preferences.v1` and `EyeRest.completions.v1`. Decoding is field-tolerant and list elements are lossy, while wholly corrupt blobs are copied to a `.corrupt` backup key. Stored legacy English default messages migrate to `nil`; `nil` means use the current localized default, while a custom message remains unchanged across languages.

`Resources/Localizable.xcstrings` contains English source keys and Vietnamese translations. EyeRest follows the system or per-app language and has no in-app language switcher. Locale changes rebuild notification categories and pending content.

## Logic tests

The root Swift package compiles only Foundation-based models, persistence, and planner files. `Tests/EyeRestLogicTests` uses explicit calendars and time zones so quiet-hours, budget fairness, identifiers, migration, corrupt backups, and lossy history decoding run without an iOS simulator. It is intentionally separate from the hand-written Xcode project.

## Device validation

Use a physical iPhone for permission-denied UI, actual delivery, Time Sensitive fallback, Done/Snooze cold launches, rapid edits, time-zone changes, Vietnamese presentation, the 20-second session, quiet-hour staggering, upgrade preservation, and largest Dynamic Type sizes. The unsigned CI artifact proves compilation and package structure only.
