# EyeRest architecture

EyeRest is a native SwiftUI iOS 17+ application. It is offline-first, contains no app network client, and has no third-party runtime dependency.

## Components

- `EyeRestApp` and `AppViewModel` own launch, persisted settings, serialized notification reconciliation, scene changes, and navigation.
- SwiftUI views render Home, Reminders, Activity, Settings, welcome, backup, and guided-break flows.
- Foundation-only models and algorithms are selected explicitly from `EyeRest/Models` and `EyeRest/Services` by `Package.swift`, so `swift test` can exercise scheduling, activity aggregation, persistence codecs, and backup behavior without Xcode.
- `NotificationPlanner` creates a bounded set of absolute local-notification requests. The app delegate handles notification responses and routes guided activities.
- `ActivityStore` writes completed-session data atomically in Application Support. Preferences use versioned Codable data with tolerant decoding and migration defaults.
- `MedicineStore` atomically stores reminders and a capped event log in `Application Support/EyeRest/medicine-v1.json`.
- `BackupCodec` validates a canonical JSON payload and SHA-256 checksum before applying settings, activity, or optional medicine data.

## Wellness scheduling precedence

For each enabled reminder kind, scheduling applies the same shared rule function until stable, with a bounded iteration count:

1. A pause moves the candidate to `pausedUntil`; indefinite pause schedules nothing.
2. An inactive weekday advances to the next active local day.
3. Quiet hours move the candidate to the next allowed time, with a stable per-kind stagger.
4. Calendar reconstruction uses local date components so daylight-saving gaps, overlaps, and time-zone changes are handled by the system calendar.

The planner creates absolute, non-repeating requests. It reconciles again after relevant edits, launch, locale or time-zone changes, and significant clock changes. Snooze uses an absolute date adjusted by the same pause, active-day, and quiet-hour rules, and is ignored while paused.

## Notification budget

iOS permits at most 64 pending local-notification requests per app. Six slots are reserved for snoozes. Medicine uses up to 28 regular slots and wellness retains at least 30; unused medicine capacity returns to wellness. Medicine ignores wellness pause, active days, and quiet hours. Requests share one thread, while identifier-aware reconciliation prevents either feature from deleting the other's requests or any snooze.

## Storage and compatibility

- Versioned preferences preserve reminder configuration, quiet hours, active days, welcome state, and UI preferences.
- Activity data stores individual recent events plus permanent daily totals. Only a fully completed guided session records an event.
- Backup schema version 2 adds optional medicine data. Version 1 remains importable without changing medicine data. Imports replace reminder definitions only when present and merge activity and medicine events by UUID.
- A failed decode or write must leave existing user data intact. New fields use defaults so upgrades keep existing settings and history.
- Notification authorization and pending operating-system requests are never backup data; the app rebuilds them after import.

## Distribution boundary

CI builds a Release app with signing disabled and packages it as an unsigned IPA. The repository contains no certificates, profiles, or signing secrets. The end user supplies signing, and optional capabilities such as Time Sensitive delivery depend on the final provisioning profile and iOS settings.
