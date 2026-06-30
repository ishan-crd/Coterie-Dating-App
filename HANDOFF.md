# Circle — Engineering Handoff

> A SwiftUI iOS app for **making friends** based on shared interests. Think
> Hinge/Bumble mechanics (one profile at a time, like / pass, a daily like
> allowance) but for platonic connection, not dating.
>
> This document is the single source of truth for the current state of the
> **frontend** and the contract the **backend / database** must fulfill. It is
> written so another model (or engineer) can pick up either side cleanly.

---

## 1. Product summary

- **Name:** Circle (display name `Circle`; the Xcode target is still `coterie-ios` — see §11 for the rename caveats).
- **Tagline:** "Find friends who share your world."
- **Core loop:** A user onboards (builds a profile of name, age, photos, city, work, prompts, interests), then on the **Explore / Today** page sees other people one at a time as a full scrolling profile. They **pass (✕)** or **like (♥)**. Likes are capped at **5 per day**. Liking someone starts a conversation that appears in **Messages**.
- **Entry gate:** Currently invite-only via a hardcoded code (`111111`). The backend should replace this with real auth (see §8).
- **Theme:** Warm editorial design (serif display type + grotesk body) on a paper background, with a warm orange accent. Full light/dark support; **defaults to System theme**.

### Current state / maturity
- The **frontend is a working prototype** driven entirely by **in-memory seed data** (`CTData` in `Models.swift`) and **`UserDefaults`** persistence (`Persistence.swift`). There is **no networking layer yet**.
- Portraits are **not real photos** — they are procedurally rendered gradients (`PortraitGradient`) standing in for images. Replacing these with real image loading is a primary backend/frontend integration task (see §6, §7).
- All "other people" (the 6 seed `Member`s) are fake. The like/pass/match/chat flows are simulated locally (e.g. chat auto-replies from a canned pool).

---

## 2. Tech stack & project layout

- **Language/UI:** Swift 5, SwiftUI. Target iOS 26.x (built & tested on iOS 26.2 simulator, iPhone 17).
- **No external dependencies.** No SPM packages, no CocoaPods.
- **State:** A single `@MainActor` `ObservableObject` `AppState` injected via `.environmentObject`. All screens read it with `@EnvironmentObject`.
- **Persistence:** `UserDefaults` via the `Persistence` enum (JSON-encoded `Codable` structs).
- **Xcode project:** `coterie-ios.xcodeproj`. Uses **synchronized folder groups** (objectVersion 77 / `PBXFileSystemSynchronizedRootGroup`) — **any file added to a folder is automatically included in the target**; you do not edit `project.pbxproj` to add files.
- **Bundle id:** `com.datecotorie.app` (main), `com.datecotorie.app.Tests`, `com.datecotorie.app.UITests`.
- **Display name:** `Circle` (set via `INFOPLIST_KEY_CFBundleDisplayName` in build settings; `GENERATE_INFOPLIST_FILE = YES`, so there is no standalone Info.plist).

### File tree
```
coterie-ios/
  coterie_iosApp.swift          // @main entry; creates AppState, shows RootView
  Models/Models.swift           // Domain models + CTData seed data
  Store/
    AppState.swift              // Single source of truth (nav, session, explore, chat)
    Persistence.swift           // UserDefaults-backed Codable storage
  Theme/Theme.swift             // Design system: colors (CT), type, components, LogoMark, PulseRings
  Views/
    RootView.swift              // Top-level router (invite / onboarding / app) + preferredColorScheme
    Components/FlowLayout.swift  // Wrapping HStack layout for chips/tags
    Onboarding/
      InviteView.swift          // Invite-code entry (accepts 111111)
      OnboardingView.swift      // Multi-step profile builder + PromptComposer
      WaitlistView.swift        // "Join the waitlist" path
    Main/
      MainTabView.swift         // Tab shell + GlassTabBar + fullScreenCover sheets
      TodayView.swift           // EXPLORE: scrolling profile, topic filters, like/pass
      GalleryView.swift         // Browse all members as cards
      InvitesView.swift         // Inbound interest list (seed data)
      MessagesView.swift        // Conversation list
      ProfileView.swift         // Own profile + Appearance/Preferences/Account settings
    Sheets/
      ProfileDetailView.swift   // Full member profile (from Gallery/Invites) + Pass/Introduce
      EditProfileView.swift     // Edit own profile (reuses onboarding building blocks)
      ChatView.swift            // 1:1 conversation with simulated replies
  Assets.xcassets/
    AppIcon.appiconset          // 1024px app icon (currently old "Coterie" art — NEEDS new Circle icon)
    coterie-logo.imageset       // Old wordmark PNG — NO LONGER USED (LogoMark renders serif text now)
    AccentColor.colorset
HANDOFF.md                      // this file
```

---

## 3. Navigation / app flow

`RootView` switches on `app.stage` (`AppStage`):
- `.invite` → `InviteView` (enter code `111111`).
- `.onboarding` → `OnboardingView` (profile builder).
- `.app` → `MainTabView` (the signed-in app).

On launch, `AppState.init` loads a saved profile; **if a complete profile exists, it jumps straight to `.app`** (skips invite + onboarding). This is the "returning user" path the backend's real auth must preserve.

`MainTabView` has 5 tabs (`MainTab`): `today` (Explore), `gallery`, `invites`, `messages`, `profile`. Sheets are presented via `fullScreenCover(item: $app.activeSheet)` where `ActiveSheet` is `.profile(id)`, `.chat(id)`, or `.edit`.

`RootView` applies `.preferredColorScheme(app.appearance.colorScheme)` — `nil` for System.

---

## 4. Domain models (`Models/Models.swift`)

### `AppStage`
`enum AppStage { case invite, onboarding, app }`

### `Member` — someone you can be matched with (REMOTE DATA in production)
```swift
struct Member: Identifiable, Hashable {
    let id: String           // stable user id
    var name: String
    var age: Int
    var city: String
    var role: String         // job/occupation, e.g. "Gallerist"
    var portrait: PortraitSeed  // PLACEHOLDER for photo(s) — replace with image URLs
    var bio: String          // short "About" blurb
    var why: String          // "why you'd get along" copy (legacy from dating framing)
    var prompts: [PromptAnswer]
    var interests: [String]  // MUST be values from CTData.interests for filtering to work
}
```

### `PromptAnswer` — a prompt + its answer (on a Member)
```swift
struct PromptAnswer: Identifiable, Hashable { var id = UUID(); var q: String; var a: String }
```

### `PromptResponse` — a prompt the signed-in user chose (on UserProfile)
```swift
struct PromptResponse: Codable, Equatable, Hashable, Identifiable {
    var id = UUID(); var promptId: String; var answer: String = ""
}
```
`promptId` references an id in `CTData.prompts`. The user may choose up to **3** (`AppState.maxPrompts`).

### `UserProfile` — the signed-in user (PERSISTED via UserDefaults today; OWNED BY BACKEND in production)
```swift
struct UserProfile: Codable, Equatable {
    var name = ""
    var dobM = ""; var dobD = ""; var dobY = ""   // day/month/year as strings; age is derived
    var photos: [PortraitSeedCodable?] = Array(repeating: nil, count: 6)  // 6 slots; PLACEHOLDER
    var pronouns = ""        // from CTData.pronouns
    var seeking = ""         // from CTData.seeking — LEGACY dating field (see §11)
    var city = ""
    var work = ""
    var prompts: [PromptResponse] = []   // up to 3
    var interests: [String] = []         // from CTData.interests; >= 3 required in onboarding

    var age: Int? { ... }                // computed from dob*, relative to today
    var filledPhotoCount: Int { ... }
    var firstPhoto: PortraitSeedCodable? { ... }
    var isComplete: Bool { !name.isEmpty && filledPhotoCount >= 2 }
}
```

### `PortraitSeed` / `PortraitSeedCodable` — PLACEHOLDER for photos
```swift
struct PortraitSeed: Hashable { var lx: Double; var ly: Double }  // light-source position 0..100
struct PortraitSeedCodable: Codable, Equatable, Hashable { var lx: Double; var ly: Double }
```
> **IMPORTANT:** These describe a *rendered gradient*, not an image. In production, replace `portrait`/`photos` with **image URLs** (or asset ids) and load them. `PortraitGradient` can stay as a loading placeholder.

### Conversations & invites
```swift
struct ChatMessage: Identifiable, Hashable, Codable { var id = UUID(); var fromMe: Bool; var text: String }
struct Conversation: Identifiable, Hashable { var id: String; var preview: String; var time: String; var unread: Bool; var messages: [ChatMessage] }
struct Invitation: Identifiable, Hashable { var id: String; var note: String; var time: String }
```
`Conversation.id` and `Invitation.id` are the **member id** of the other party.

---

## 5. Reference data (`CTData` enum in `Models.swift`)

This is the **seed data** the backend must eventually serve. Keep these vocabularies in sync between client and server (or have the server send them).

### `pronouns`
`["She / Her", "He / Him", "They / Them"]`

### `seeking` (LEGACY dating field — see §11)
`["Women", "Men", "Everyone"]`

### `cities`
`["Paris", "London", "New York", "Copenhagen", "Lisbon", "Stockholm"]`

### `interests` — the canonical topic vocabulary (drives matching/filtering)
```
"Hiking", "Music", "Content creation", "Photography", "Cooking", "Gaming",
"Running", "Coffee", "Art", "Film", "Books", "Travel", "Yoga", "Cycling",
"Design", "Dancing", "Climbing", "Wine", "Sailing", "Surfing", "Gardening", "Vinyl"
```
> Both `UserProfile.interests` and `Member.interests` must draw from this list for the Explore topic filter to find overlaps. The user's chosen interests become the **topic chips** on Explore; a candidate matches a topic if they share that interest.

### `prompts` — `[(id, q)]`, user picks up to 3
ids: `sunday, fall, win, alive, view, dinner, travel, weekend, simple, learning, laugh, brave, song, home, overrated, ritual, kindness, greenflag, project, first, childhood, comfort` (22 total; see file for question text). `CTData.promptText(id)` resolves a question.

### `members` — 6 seed people (fake)
`margot, elias, saoirse, cyrus, ingrid, theo` — each with name/age/city/role/portrait/bio/why/prompts/interests. `CTData.member(id)` looks one up. Their interests were retagged to the mainstream `interests` vocabulary so filtering produces matches.

### `invitations`, `replyPool`
Seed inbound interest + a canned pool of fake chat replies used to simulate the other person responding.

### `photoPositions`
Six fixed `PortraitSeed`s used when the user "adds" a photo in onboarding (placeholder behavior).

---

## 6. AppState — the behavior contract (`Store/AppState.swift`)

`@MainActor final class AppState: ObservableObject`. Key published state and methods (these are the seams the backend replaces):

### Navigation / session
- `stage: AppStage`, `tab: MainTab`, `activeSheet: ActiveSheet?`
- `inviteCode`, `verifying`, `inviteError`, `onboardingStep`
- `validInviteCode = "111111"` (static) — **replace with real auth.**
- `onInviteChanged(_:)` — validates the code locally with a fake delay. **Backend: real invite/auth check.**

### Profile
- `profile: UserProfile`
- `bind(_:)`, `digitBind(_:_:)` — two-way bindings into profile fields for the forms.

### Onboarding
- `steps: [OnboardingStep]` = all cases of `enum OnboardingStep { welcome, name, birthday, photos, about, city, work, prompt, interests, review }` (10 steps; the old `intention` "What brings you here" step was removed).
- `canAdvance(from:)` — per-step validation (e.g. name ≥ 2 chars, ≥ 2 photos, ≥ 3 interests, every chosen prompt answered).
- `advanceOnboarding()`, `backOnboarding()`, `completeOnboarding()` (persists profile, enters app).
- Prompt management: `maxPrompts = 3`; `availablePrompts`, `addPrompt(_:)`, `removePrompt(_:)`, `promptAnswerBind(_:)`.
- Photos: `togglePhoto(_:)` (placeholder — adds/removes a gradient seed). **Backend: real photo upload/picker.**
- Interests: `toggleInterest(_:)`.

### Explore / discovery (the core friend-finding loop)
- `exploreTopics: Set<String>` — selected topic filter (empty = everyone).
- `passedIDs: Set<String>`, `likedIDs: Set<String>` — local session tracking.
- `likesRemaining: Int` (daily allowance, `dailyLikeLimit = 5`).
- `exploreCandidates: [Member]` — filters `CTData.members` by not-passed, not-liked, and topic overlap. **Backend: this becomes a paginated discovery/recommendation feed request.**
- `myTopics` → `profile.interests` (the chips shown).
- `toggleTopic(_:)`, `clearTopics()`, `sharedInterests(_:)`.
- `passMember(_:)` — adds to `passedIDs`. **Backend: record a pass.**
- `likeMember(_:)` — guards `likesRemaining > 0`, decrements, persists, and **seeds a local Conversation** ("You connected — say hello."). **Backend: record a like, run match logic, create/return a conversation only on mutual match (or per product rules).**
- `resetDeck()` — clears `passedIDs` (the "Start Over" empty-state button).

### Daily likes reset
- `loadLikes()` / `persistLikes()` use `Persistence` + a `yyyy-MM-dd` `todayKey`. On a new calendar day the allowance resets to 5. **Backend: enforce the limit server-side (clients can't be trusted).**

### Conversations / chat (simulated)
- `conversations: [String: Conversation]`, `conversationOrder: [String]`, `typing: Bool`.
- `openChat(with:seeding:)` — opens the chat sheet & switches to Messages tab.
- `send(_:to:)` — appends the user's message, then **fakes** a reply after a delay from `CTData.replyPool`. **Backend: real realtime messaging (WebSocket/push).**
- `seedConversations()` — two fake threads on launch.

### Settings (persisted)
- `notifications`, `paused`, `appearance: AppearanceMode` (default `.system`). Persisted via `StoredSettings`.

### Account
- `logout()` — clears profile + local state, returns to `.invite`.

### DEBUG preview seams
`applyPreviewLaunchArguments()` reads launch args: `-previewApp` (jump to app with `UserProfile.sample`), `-previewTab <gallery|invites|messages|profile>`, `-previewOnboarding` + `-previewStep N`, `-previewDark`. Used for screenshots/testing.

---

## 7. Persistence today vs. backend target (`Store/Persistence.swift`)

Currently everything is local `UserDefaults` JSON:
- `StoredSettings { notifications, paused, appearance }` → key `coterie.settings`
- `UserProfile` → key `coterie.profile`
- `StoredLikes { day, remaining }` → key `coterie.likes`
- `Persistence.clear()` wipes the profile on logout (settings preserved).

**Backend migration plan:**
- Profile, photos, prompts, interests → server-owned, fetched on login.
- Likes allowance + pass/like history → server-owned and enforced.
- Conversations/messages → server-owned, realtime.
- Keep `Persistence` as a thin local cache (offline support) if desired.

---

## 8. Backend / API surface to build

The frontend currently has **no network layer**. Recommended endpoints (REST or GraphQL — your call). All authed unless noted.

### Auth / onboarding
- `POST /auth/verify-invite` `{ code }` → `{ valid, token? }` (replaces `validInviteCode`).
- `POST /auth/session` (sign in / sign up) → `{ token, profileComplete }`.
- `GET /me` → `UserProfile`.
- `PUT /me` → update profile (name, dob, city, work, pronouns, prompts, interests).
- `POST /me/photos` (multipart) → upload a photo; returns an image URL/id. `DELETE /me/photos/{id}`. (Replaces the gradient placeholder system — see §6 photos.)

### Discovery (Explore feed)
- `GET /discovery?topics=Hiking,Music&cursor=...` → paginated `[Member]` excluding already passed/liked, ranked by shared interests. (Replaces `exploreCandidates`.)
- `POST /interactions` `{ targetId, action: "like" | "pass" }` → `{ likesRemaining, matched?: bool, conversationId? }`. Server enforces the **5/day** like cap and resets daily.
- `GET /likes/allowance` → `{ remaining, resetsAt }`.

### Matches & messaging
- `GET /conversations` → `[Conversation]` (ordered).
- `GET /conversations/{id}/messages?cursor=...`
- `POST /conversations/{id}/messages` `{ text }` (or WebSocket send).
- Realtime: WebSocket/SSE for incoming messages + typing indicators (currently faked client-side).
- Push notifications for new likes/matches/messages (there's a `notifications` preference toggle already).

### Invites (inbound interest)
- `GET /invitations` → `[Invitation]` (people who liked you, if product surfaces this).

### Reference data (optional but recommended)
- `GET /config` → `{ interests[], prompts[], cities[], pronouns[] }` so the vocab isn't hardcoded in the client. Until then, **keep `CTData.interests` / `CTData.prompts` identical on both sides.**

### Data model mapping notes for the backend
- `Member.portrait` (PortraitSeed) → replace with `photos: [URL]`.
- `UserProfile.photos` (6 `PortraitSeedCodable?` slots) → `photos: [Photo]` with order.
- `UserProfile.dobD/dobM/dobY` strings → a real date; age is derived client-side today.
- Interests/prompt ids are **strings**; keep them stable.

---

## 9. Design system (`Theme/Theme.swift`)

All UI pulls from here. Do not hardcode colors/fonts in views.

### Color tokens — `enum CT` (every token is light/dark adaptive via `Color.dyn(light, dark)`)
- Surfaces: `paper` (app bg), `surface` (cards/fields).
- Text/ink: `ink` (primary), `ink90/80/70`, `body`, `bodyLight`, `muted`, `faint`, `fainter`, `tabIdle`.
- **Accent (warm orange):** `accent` = `#E0674A` (light) / `#F07E5E` (dark); `accentInk` (text on accent); `accentSoft` (tinted bg). Used for primary CTAs, selected chips/rows, active tab, like button, sent chat bubbles.
- Lines/fills: `hairline`, `hairlineSoft`, `border`, `borderStrong`, `fill`, `disabledFill`, `disabledInk`.
- Component: `bubbleThem`, `photoEmpty`.
- `Color(hex:)` initializer and `Color.dyn(_:_:)` helper live here.

### Typography — `Font.serif(_:weight:)` (New York / serif display) and `Font.grotesk(_:weight:)` (system default). View helpers: `.serifItalic(_:)`, `.eyebrow(_:tracking:)`.

### Theme mode — `enum AppearanceMode { system, light, dark }`; `colorScheme: ColorScheme?` returns `nil` for system. **Default is `.system`** (follows the device). Selectable in Profile → Appearance.

### Reusable components (in Theme.swift unless noted)
- `LogoMark(height:color:)` — the **"Circle" wordmark, rendered as serif Text** (NOT an image anymore). Scales font to `height`.
- `PulseRings(color:size:)` — animated expanding-rings "searching" ornament (used in Explore empty state; reusable).
- `PillButton(title:style:enabled:action:)` — primary/outline/ghost capsule button (filled = accent).
- `PressableStyle(scale:)` — press scale-down button style.
- `ChoiceChip`, `ChoiceRow` — selectable chip / row (selected = accent).
- `UnderlineField` — the signature underlined serif text field.
- `AnswerEditor` (in OnboardingView.swift) — bordered multiline answer box.
- `TagPill` (in ProfileView.swift) — outlined interest pill.
- `FlowLayout` (Views/Components) — wrapping layout for chips/tags.

---

## 10. Key screens (current behavior)

- **InviteView** — code entry, accepts `111111`; quiet path to `WaitlistView`. Hero shows `LogoMark` + tagline "Find friends who share your world."
- **OnboardingView** — 10 steps (welcome, name, birthday DD/MM/YYYY, photos, about [pronouns + seeking], city, work, **prompts (PromptComposer: pick up to 3 from the list, answer each inline)**, interests [≥3], review). `PromptComposer` is reused in EditProfileView.
- **TodayView (EXPLORE)** — THE primary screen. Top bar: `LogoMark`, "N likes left", and a horizontal scroll of **topic filter chips** (Everyone + the user's interests). Body: the current candidate shown as a **full vertical scroll** of interleaved **photos and prompt/about/shared/interests cards**. **Static ✕ (pass, left) and ♥ (like, right)** float over the scroll, pinned above the tab bar. Empty state uses `PulseRings`.
- **GalleryView** — browse all `CTData.members` as cards → opens `ProfileDetailView`.
- **InvitesView** — inbound interest (seed data).
- **MessagesView** — conversation list → opens `ChatView`.
- **ProfileView** — own profile (photos/prompts/interests), Edit Profile, **Appearance (System/Light/Dark)**, preferences (notifications, pause), account (logout). Footer text "Circle · Find your people".
- **ProfileDetailView** — full member profile from Gallery/Invites; footer **Pass / Introduce Yourself** (tight bottom padding so it hugs the phone bottom). NOTE: "Introduce Yourself" is legacy dating copy (see §11).
- **ChatView** — 1:1 chat with **simulated** replies; sent bubbles use accent.
- **EditProfileView** — edit own profile, reuses onboarding building blocks + `PromptComposer`.

---

## 11. Known legacy / dating-era leftovers to reconcile (friend-app pivot)

The app began as an **invite-only dating app ("Coterie")** and was pivoted to a **friends app ("Circle")**. Some dating-era concepts remain and should be reviewed for the friend framing:

1. **`UserProfile.seeking` + `CTData.seeking` (`Women/Men/Everyone`) and the onboarding "Interested in meeting" step** — dating-oriented. Decide whether to drop or repurpose (e.g. "who you want to meet").
2. **`ProfileDetailView` footer "Introduce Yourself"** CTA + the `Member.why` ("why you were introduced") field — dating-era copy. Consider "Say Hi" / "Add Friend".
3. **Invite-only gate** (`111111`) — likely becomes open signup with real auth.
4. **App icon (`AppIcon.appiconset`) still shows the old "Coterie" art**, and `coterie-logo.imageset` is now **unused** (LogoMark is serif text). Provide a new **Circle** icon (single opaque 1024px, no alpha) and drop or replace the imageset.
5. **Xcode target/folder is still named `coterie-ios`** and bundle id is `com.datecotorie.app` (contains "cotorie"). Renaming the target is optional/cosmetic; the user-facing display name is already `Circle`.
6. Copy throughout still leans editorial/curated ("The Gallery", "Curated for you", "Introduced by Circle" → already partly updated). Audit for friend-tone.

---

## 12. Build / run / test

- **Open:** `coterie-ios.xcodeproj` in Xcode (iOS 26 SDK).
- **Build (CLI):**
  ```
  xcodebuild -project coterie-ios.xcodeproj -scheme coterie-ios \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath /tmp/coterie-dd build
  ```
- **Run a preview state on the simulator** (DEBUG launch args), e.g. land on Explore:
  ```
  xcrun simctl launch booted com.datecotorie.app -previewApp -previewTab today
  ```
  Add `-previewDark` to force dark, or `-previewOnboarding -previewStep N`.
- **Source of truth for correctness is `xcodebuild`.** SourceKit/IDE may show false "Cannot find type 'X' in scope" cross-file errors that are not real — trust a clean `xcodebuild`.
- **Adding files:** drop them in the right folder; synchronized groups auto-include them (no pbxproj edits).

---

## 13. Suggested next steps for the backend model

1. Stand up auth + `/me` profile CRUD; wire `AppState.onInviteChanged` / onboarding completion to real endpoints (keep the "returning user skips onboarding" behavior keyed off `profileComplete`).
2. Real photo upload + image loading (replace `PortraitGradient`/`PortraitSeed` with URLs; use `AsyncImage` or a small loader with `PortraitGradient` as the placeholder).
3. Discovery feed endpoint (`exploreCandidates` → paginated server feed by topics) + server-enforced 5/day like cap and pass/like recording with match logic.
4. Realtime messaging (replace the simulated `send`/`replyPool`) + push notifications.
5. Optional `/config` to serve interests/prompts/cities so vocab isn't duplicated.
6. Resolve the dating-era leftovers in §11 with product.

> Keep the client's `CTData.interests` and `CTData.prompts` **byte-for-byte in sync** with the server vocabulary until `/config` exists, or matching/filtering breaks silently.
