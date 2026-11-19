# EyeRest consolidation and hardening

## Intent

Consolidate the existing static landing page and the separately generated native iOS source into one repository without representing the iOS app as built on Windows. Fix verified website and source-level issues, preserve the website commit history, and make GitHub Pages deploy only the website.

## User outcome and success criteria

The public repository contains a working, responsive website and a clearly separated SwiftUI project. The website has no avoidable third-party runtime dependency, all local paths work from the Pages subpath, and the repository documents the app’s actual validation state. Pages deploys only website files. The iOS source remains ready for Xcode validation on macOS.

## Scope and non-goals

In scope: repository layout, Pages path, static website correctness and responsive QA, source-level iOS review, root documentation, and automated static checks runnable on Windows. Out of scope: compiling or packaging iOS on Windows, claiming an IPA exists, changing the app’s product design, adding a backend, or adding AI features. No AI runtime, model, prompt, or AI dependency exists in the inspected sources.

## Evidence and current behavior

- `index.html`, `assets/styles.css`, and `assets/main.js` implement a dependency-free landing page, but `index.html` loads Google Fonts and includes a visual-only `<button>` with no action.
- `.github/workflows/pages.yml` publishes repository root, which conflicts with adding iOS source at the same root.
- `docs/IOS_DEVELOPMENT.md` correctly states macOS/Xcode limitations but is website-specific rather than monorepo documentation.
- `C:/Users/go548/Documents/Codex/2026-11-19/new-chat/EyeRest` contains a complete SwiftUI/Xcode source tree, README, validation log, and unsigned archive script; it has no Git metadata.
- `EyeRest/Services/NotificationService.swift` owns local scheduling. `EyeRest/ViewModels/AppViewModel.swift` owns persistence/reconciliation. `EyeRest/Views/HomeView.swift` renders next reminder state.
- The current Pages workflow is the only automation. No secrets, network clients, package manifests, or AI implementation were found in either project.

## Baseline Design Inventory

| ID | Existing decision / location | Current assumption | Why it matters now | Pressure signal |
|---|---|---|---|---|
| B1 | Static page at repository root | Root is the deployable site | Adding iOS source would publish it as Pages artifact | Workflow uploads `.` |
| B2 | Google-hosted font stylesheet in `index.html` | External typography is acceptable | It adds a third-party request and failure point | Privacy-first product message |
| B3 | Mock phone uses `button.pause-demo` | The control is visual-only | A button implies an available action to keyboard and screen-reader users | No listener or behavior exists |
| B4 | Website history in current Git repository | Two commits describe site/docs creation | Preserve it when reorganizing | Valid local history exists |
| B5 | iOS source under `new-chat/EyeRest` | It is a separate project | It must live alongside web source without exposing build artifacts | No Git history / Windows cannot compile it |
| B6 | Notification scheduler and view model | Scheduler owns pending local notification requests; view model owns persistent next dates | Source review must avoid moving this boundary without tests | macOS toolchain unavailable |
| B7 | Home display | `nextDate` derives from enabled reminders even when app is paused | Pause is expected to present as paused state | User-visible state mismatch |

## Proposed behavior and architecture

The repository becomes a lightweight monorepo: `website/` contains only Pages content, `ios/` contains the Xcode project, `docs/` contains product and platform documentation, and `.github/` owns automation. The Pages workflow uploads `website/`. The root README is the project map and verification entry point. Website font rendering uses local system font stacks and the mock control is non-interactive markup. The iOS pause state is reflected by the next-reminder presentation without changing scheduling ownership.

## Proposed Design Ledger

| ID | Proposed decision | Location / owner | Reason | Assumption or risk | Related baseline IDs |
|---|---|---|---|---|---|
| D1 | Move static site to `website/`; upload only that path | GitHub Pages workflow | Separates public web artifact from native source | Pages setting must use GitHub Actions | B1, B5 |
| D2 | Retain the existing Google Fonts request with local system fallbacks | `website/index.html`, CSS | Preserves the deliberate visual typography and avoids a broken fallback experience | Font delivery depends on Google Fonts availability | B2 |
| D3 | Change visual mock pause element to non-interactive status | `website/index.html` | Matches semantics to actual behavior | No interaction is intended on a landing-page mockup | B3 |
| D4 | Retain existing commits via `git mv`; add iOS source in a new commit | Git repository | Preserves practical web history and makes origin clear | External iOS source has no history to preserve | B4, B5 |
| D5 | Copy iOS project verbatim under `ios/`, amend pause-state derivation only | `ios/EyeRest` | Keeps scheduling/persistence ownership intact while resolving UI state mismatch | Full iOS build requires macOS | B5, B6, B7 |
| D6 | Add static validation script runnable on Windows | `scripts/verify-repository.mjs` | Gives repeatable coverage where Xcode is unavailable | It is not a substitute for `xcodebuild` | B5, B6 |

## Compression Review

| Review ID | Baseline / decision ID | Pressure or conflict | Finding | Action | Required design update |
|---|---|---|---|---|---|
| C1 | B1 / D1 | Root deployment would include iOS project | One workflow path change is smaller than exclusions or duplicated sites | rewrite | Make `website/` the sole artifact path |
| C2 | B2 / D2 | Removing the font changed the visual design materially | The public site’s typography is part of its intended design; system stacks remain fallbacks | keep | Retain the existing Google Font links |
| C3 | B3 / D3 | Nonfunctional button is misleading and inaccessible | Semantics, not a new interaction, is the narrow fix | rewrite | Replace button with neutral visual element |
| C4 | B4 / D4 | User asked to preserve history where practical | `git mv` preserves history; importing external code cannot preserve absent history | keep + merge | Retain web commit lineage and add one import commit |
| C5 | B6 / D5 | Broad scheduler refactor cannot be compiled here | Scheduler ownership is coherent; only visible paused state is verified incorrect | defer + rewrite | Do not change scheduler; derive no next reminder when paused |
| C6 | B5 / D6 | Windows cannot execute iOS tests | Static inspection is useful but insufficient for runtime proof | split | Clearly separate Windows checks from macOS Xcode validation |

## Design iteration log

| Iteration | Main question | New evidence | Decisions changed | Remaining uncertainty |
|---|---|---|---|---|
| 1 | Can the website and iOS source share root deployment? | Workflow uploads `.` | D1 | Pages source UI must be set to Actions |
| 2 | Are website controls and dependencies truthful? | Google font links and inert button observed | D2, D3 | Font availability is mitigated by system fallbacks |
| 3 | Is iOS scheduling safe to refactor on Windows? | Scheduler/view model boundary and lack of Xcode observed | D5, D6 | Runtime notification behavior needs macOS/device validation |

## Edge cases and validation

Pages subpath is handled through relative asset URLs. A paused app must not imply that a next reminder remains active. Validate the website at desktop and 375px width; check page landmark/link/asset consistency and workflow artifact path. Validate iOS project file references, deployment target, bundle identifier, entitlement, no network SDKs, and source presence on Windows. On macOS, run the documented `xcodebuild` and device notification test matrix before making an app-build claim.

## Deferred risks

The exact Xcode compile and local-notification delivery behavior cannot be verified on Windows. A future macOS pass should add XCTest coverage around quiet-hours boundaries, rescheduling after timezone changes, and notification-action persistence.
