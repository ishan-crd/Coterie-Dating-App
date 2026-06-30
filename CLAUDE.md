# CLAUDE.md

Circle — a SwiftUI iOS **make-friends** app (like/pass on profiles by shared
interests, 5 likes/day). Full architecture, models, data, and the backend/API
contract are in **`HANDOFF.md`** — read it before substantial work.

## Build & run

```bash
# Build (source of truth for correctness)
xcodebuild -project coterie-ios.xcodeproj -scheme coterie-ios \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/coterie-dd build

# Launch a preview state on the booted simulator (DEBUG launch args)
xcrun simctl install booted /tmp/coterie-dd/Build/Products/Debug-iphonesimulator/coterie-ios.app
xcrun simctl launch booted com.datecotorie.app -previewApp -previewTab today
# extra args: -previewDark | -previewOnboarding -previewStep N | -previewTab gallery|invites|messages|profile
```

If "iPhone 17" isn't available, list devices with `xcrun simctl list devices available`.

## Conventions / gotchas

- **Trust `xcodebuild`, not the IDE.** SourceKit shows false cross-file
  "Cannot find type 'X' in scope" errors that are NOT real. A clean `xcodebuild`
  is the only correctness signal.
- **Synchronized folder groups** (objectVersion 77): any file added to a folder
  is auto-included in the target. Do **not** hand-edit `project.pbxproj` to add files.
- **Design system lives in `Theme/Theme.swift`** (`CT` color tokens, `Font.serif`/
  `Font.grotesk`, shared components). Don't hardcode colors/fonts in views.
- **Single state object:** `AppState` (`@MainActor ObservableObject`), injected via
  `.environmentObject`, read with `@EnvironmentObject`. No networking layer yet —
  data is seed (`CTData` in `Models.swift`) + `UserDefaults` (`Persistence.swift`).
- **Theme defaults to System** (follows the device); user can override to Light/Dark.
- **Bundle id** `com.datecotorie.app`; **display name** `Circle`. The Xcode target/
  folder is still named `coterie-ios` (cosmetic legacy).
- **User photos are real uploads** — `PhotosPicker` → `AppState.setPhoto` (downscaled JPEG `Data` in `UserProfile.photos`, persisted in `UserDefaults`); rendered via `ProfilePhoto`. Only **other people's** photos (`Member.portrait`) are still `PortraitGradient` placeholders.
- Keep `CTData.interests` and `CTData.prompts` in sync with any backend vocabulary,
  or matching/filtering breaks silently.

## Pivot note

The app was pivoted from a dating app ("Coterie") to a friends app ("Circle").
Some dating-era leftovers remain (the `seeking` onboarding step, "Introduce
Yourself" CTA, invite-only gate, old app-icon art). See **§11 of `HANDOFF.md`**
before "fixing" anything that looks dating-flavored — it may be a known leftover.
