# EyeRest architecture

EyeRest is a native SwiftUI iOS 17+ application. It is offline-first, contains no app network client, and has no third-party runtime dependency.

## Components

- `EyeRestApp` and `AppViewModel` own launch, persisted settings, serialized notification reconciliation, scene changes, and navigation.
- SwiftUI views render Home, Reminders, Activity, Settings, welcome, backup, and guided-break flows.
- Foundation-only models and algorithms are selected explicitly from `EyeRest/Models` and `EyeRest/Services` by `Package.swift`, so `swift test` can exercise scheduling, activity aggregation, persistence codecs, and backup behavior without Xcode.
- `NotificationPlanner` creates a bounded set of absolute local-notification requests. The app delegate handles notification responses and routes guided activities.
- `ActivityStore` writes completed-session data atomically in Application Support. Preferences use versioned Codable data with tolerant decoding and migration defaults.
- `BackupCodec` validates a canonical JSON payload and SHA-256 checksum before applying settings or activity data.

## Wellness scheduling precedence

For each enabled reminder kind, scheduling applies the same shared rule function until stable, with a bounded iteration count:

1. A pause moves the candidate to `pausedUntil`; indefinite pause schedules nothing.
2. An inactive weekday advances to the next active local day.
3. Quiet hours move the candidate to the next allowed time, with a stable per-kind stagger.
4. Calendar reconstruction uses local date components so daylight-saving gaps, overlaps, and time-zone changes are handled by the system calendar.

The planner creates absolute, non-repeating requests. It reconciles again after relevant edits, launch, locale or time-zone changes, and significant clock changes. Snooze uses an absolute date adjusted by the same pause, active-day, and quiet-hour rules, and is ignored while paused.

## Notification budget

iOS permits at most 64 pending local-notification requests per app. EyeRest currently plans at most 58 wellness requests and leaves six slots for snoozes. Requests share one thread identifier and use quick or guided categories chosen at scheduling time. Rapid edits pass through a serialized reconcile and diff so obsolete requests are removed without duplicate additions.

## Storage and compatibility

- Versioned preferences preserve reminder configuration, quiet hours, active days, welcome state, and UI preferences.
- Activity data stores individual recent events plus permanent daily totals. Only a fully completed guided session records an event.
- Backup schema version 1 exports settings and activity data. Import validates format, supported schema, checksum, and value ranges before replacing settings and merging activity events by UUID.
- A failed decode or write must leave existing user data intact. New fields use defaults so upgrades keep existing settings and history.
- Notification authorization and pending operating-system requests are never backup data; the app rebuilds them after import.

## Distribution boundary

CI builds a Release app with signing disabled and packages it as an unsigned IPA. The repository contains no certificates, profiles, or signing secrets. The end user supplies signing, and optional capabilities such as Time Sensitive delivery depend on the final provisioning profile and iOS settings.
