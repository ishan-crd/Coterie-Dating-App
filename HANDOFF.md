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

- **Name:** Circle (display name `Circle`; the Xcode project, target, and folder are all `Circle`).
- **Tagline:** "Find friends who share your world."
- **Core loop:** A user onboards (builds a profile of name, age, photos, city, work, prompts, interests), then on the **Explore / Today** page sees other people one at a time as a full scrolling profile. They **pass (✕)** or **like (♥)**. Likes are capped at **5 per day**. Liking someone starts a conversation that appears in **Messages**.
- **Entry gate:** Real auth via `AuthView` — Sign in with Apple (native), Google (native) and email OTP through Supabase Auth. No invite gate.
- **Theme:** Warm editorial design (serif display type + grotesk body) on a paper background, with a warm orange accent. Full light/dark support; **defaults to System theme**.

### Current state / maturity
- The app is **fully wired to the live Supabase backend** (§8) via `Store/SupabaseService.swift`: real auth, real profiles, real discovery/likes/matches, real chat with realtime, real photo upload/download.
- **User photos are real uploads** — `PhotosPicker` → downscaled JPEG `Data` in local slots → uploaded to the `photos` bucket on onboarding-complete / edit-save; other people's photos are downloaded from the bucket and cached in `AppState.memberPhotos`. `PortraitGradient` remains as the placeholder for members with no photos.
- `CTData` is now only a **fallback vocabulary + DEBUG preview seed** (`-previewApp` etc. run fully offline).
- **Provider setup still needed in dashboards** (user-side): Apple (bundle id in Supabase Apple provider + Sign in with Apple capability on the App ID), Google (iOS OAuth client + "Skip nonce checks" in Supabase Google provider), email OTP (Send Email Hook + Resend — see §8 Auth; verify the sending domain in Resend, set the three edge-function secrets, OTP length = 6).

---

## 2. Tech stack & project layout

- **Language/UI:** Swift 5, SwiftUI. Target iOS 26.x (built & tested on iOS 26.2 simulator, iPhone 17).
- **Dependencies:** one SPM package — **supabase-swift** (declared directly in `project.pbxproj`).
- **State:** A single `@MainActor` `ObservableObject` `AppState` injected via `.environmentObject`. All screens read it with `@EnvironmentObject`. All networking goes through `Store/SupabaseService.swift`.
- **Persistence:** server-owned data on Supabase; `UserDefaults` (via `Persistence`) keeps only local preferences (+ a local profile cache).
- **Xcode project:** `Circle.xcodeproj`. Uses **synchronized folder groups** (objectVersion 77 / `PBXFileSystemSynchronizedRootGroup`) — **any file added to a folder is automatically included in the target**; you do not edit `project.pbxproj` to add files.
- **Bundle id:** `com.circlein.app` (main), `com.circlein.app.Tests`, `com.circlein.app.UITests`.
- **Display name:** `Circle` (set via `INFOPLIST_KEY_CFBundleDisplayName` in build settings; `GENERATE_INFOPLIST_FILE = YES`, so there is no standalone Info.plist).

### File tree
```
Circle/
  CircleApp.swift          // @main entry; creates AppState, shows RootView
  Models/Models.swift           // Domain models + CTData seed data
  Store/
    AppState.swift              // Single source of truth (nav, session, explore, chat)
    Persistence.swift           // UserDefaults-backed Codable storage
  Theme/Theme.swift             // Design system: colors (CT), type, components, LogoMark, PulseRings
  Views/
    RootView.swift              // Top-level router (invite / onboarding / app) + preferredColorScheme
    Components/FlowLayout.swift  // Wrapping HStack layout for chips/tags
    Onboarding/
      AuthView.swift            // Sign-in: Apple / Google / phone OTP (+ PhoneAuthSheet)
      OnboardingView.swift      // Multi-step profile builder + PromptComposer
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
    circle-logo.imageset       // Old wordmark PNG — NO LONGER USED (LogoMark renders serif text now)
    AccentColor.colorset
HANDOFF.md                      // this file
```

---

## 3. Navigation / app flow

`RootView` switches on `app.stage` (`AppStage`):
- `.loading` → logo + PulseRings while the session is checked.
- `.auth` → `AuthView` (Apple / Google / phone).
- `.onboarding` → `OnboardingView` (profile builder).
- `.app` → `MainTabView` (the signed-in app).

On launch, `AppState.init` loads a saved profile; **if a complete profile exists, it jumps straight to `.app`** (skips invite + onboarding). This is the "returning user" path the backend's real auth must preserve.

`MainTabView` has 5 tabs (`MainTab`): `today` (Explore), `gallery`, `invites`, `messages`, `profile`. Sheets are presented via `fullScreenCover(item: $app.activeSheet)` where `ActiveSheet` is `.profile(id)`, `.chat(id)`, or `.edit`.

`RootView` applies `.preferredColorScheme(app.appearance.colorScheme)` — `nil` for System.

---

## 4. Domain models (`Models/Models.swift`)

### `AppStage`
`enum AppStage { case loading, auth, onboarding, app }` (lives in AppState.swift)

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
    var photos: [Data?] = Array(repeating: nil, count: 6)   // 6 slots; REAL uploaded JPEG data (downscaled)
    var pronouns = ""        // from CTData.pronouns
    var seeking = ""         // from CTData.seeking — LEGACY dating field (see §11)
    var city = ""
    var work = ""
    var prompts: [PromptResponse] = []   // up to 3
    var interests: [String] = []         // from CTData.interests; >= 3 required in onboarding

    var age: Int? { ... }                // computed from dob*, relative to today
    var filledPhotoCount: Int { ... }
    var firstPhoto: Data? { ... }        // first non-nil uploaded photo
    var isComplete: Bool { !name.isEmpty && filledPhotoCount >= 2 }
}
```
> User photos are **real images** now: `[Data?]` of (downscaled, quality ~0.72, max 1080px, opaque) JPEG. `PortraitSeedCodable` is retained in the file but is **unused/legacy**. `Member.portrait` (other people) is still a `PortraitSeed` gradient placeholder.

### `PortraitSeed` / `PortraitSeedCodable` — gradient placeholder (for Members only)
```swift
struct PortraitSeed: Hashable { var lx: Double; var ly: Double }  // light-source position 0..100
struct PortraitSeedCodable: Codable, Equatable, Hashable { var lx: Double; var ly: Double }  // LEGACY/UNUSED
```
> `PortraitSeed` describes a *rendered gradient*, not an image — still used for **`Member.portrait`** (the fake other people). In production, replace `Member.portrait` with **image URLs** and load them; `PortraitGradient` can stay as a loading placeholder. `PortraitSeedCodable` is now unused (the user's photos became real `Data`).

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
Six fixed `PortraitSeed`s — **now legacy/unused** (the user uploads real photos via `PhotosPicker`; this was the old gradient-placeholder behavior).

---

## 6. AppState — the behavior contract (`Store/AppState.swift`)

`@MainActor final class AppState: ObservableObject`. Key published state and methods (these are the seams the backend replaces):

### Navigation / session
- `stage: AppStage`, `tab: MainTab`, `activeSheet: ActiveSheet?`
- `inviteCode`, `verifying`, `inviteError`, `onboardingStep`
- `onInviteChanged(_:)` — validates the code locally with a fake delay. **Backend: real invite/auth check.**

### Profile
- `profile: UserProfile`
- `bind(_:)`, `digitBind(_:_:)` — two-way bindings into profile fields for the forms.

### Onboarding
- `steps: [OnboardingStep]` = all cases of `enum OnboardingStep { welcome, name, birthday, photos, about, city, work, prompt, interests, review }` (10 steps; the old `intention` "What brings you here" step was removed).
- `canAdvance(from:)` — per-step validation (e.g. name ≥ 2 chars, ≥ 2 photos, ≥ 3 interests, every chosen prompt answered).
- `advanceOnboarding()`, `backOnboarding()`, `completeOnboarding()` (persists profile, enters app).
- Prompt management: `maxPrompts = 3`; `availablePrompts`, `addPrompt(_:)`, `removePrompt(_:)`, `promptAnswerBind(_:)`.
- Photos: `setPhoto(_ index:_ data:)` (downscales via `downscaledJPEG` then stores) and `removePhoto(_ index:)`. The picker UI is `PhotoSlot`/`PhotoGrid` using SwiftUI `PhotosPicker` (see §10/§9). **Backend: in `setPhoto`, also upload the image and store the returned remote URL.**
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
- `logout()` — signs out of Supabase, clears local state, returns to `.auth`.

### DEBUG preview seams
`applyPreviewLaunchArguments()` reads launch args: `-previewApp` (jump to app with `UserProfile.sample`), `-previewTab <gallery|invites|messages|profile>`, `-previewOnboarding` + `-previewStep N`, `-previewDark`. Used for screenshots/testing.

---

## 7. Persistence today vs. backend target (`Store/Persistence.swift`)

Currently everything is local `UserDefaults` JSON:
- `StoredSettings { notifications, paused, appearance }` → key `circle.settings`
- `UserProfile` → key `circle.profile`
- `StoredLikes { day, remaining }` → key `circle.likes`
- `Persistence.clear()` wipes the profile on logout (settings preserved).

**Backend migration plan:**
- Profile, photos (currently real JPEG `Data` in the local profile), prompts, interests → server-owned, fetched on login; photos uploaded to object storage.
- Likes allowance + pass/like history → server-owned and enforced.
- Conversations/messages → server-owned, realtime.
- Keep `Persistence` as a thin local cache (offline support) if desired.

---

## 8. Backend — IMPLEMENTED on Supabase

The backend is **built and live** on Supabase (project url `https://zkoweftcxxnmytnezmcf.supabase.co`). Postgres schema + RLS + RPCs + storage + realtime are all applied via migrations (`core_schema`, `interactions_matching_messaging`, `rls_policies`, `storage_and_realtime`, `seed_vocabularies`, `advisor_fixes`, `function_grants_lockdown`). **The iOS app IS wired to it** via `Store/SupabaseService.swift` (supabase-swift SPM package, publishable key baked in): auth (`AuthView` — Apple id-token / Google OAuth / phone OTP), profile sync (`pushProfile` on onboarding-complete & edit-save, photos uploaded to the bucket from dirty slots), discovery (`refreshFeed` → `get_discovery_feed`), like/pass (`act_on_profile`), likers (`get_likers`), matches+messages (`refreshConversations` + realtime channel on `messages` inserts). `CTData` remains only as vocab fallback and DEBUG preview seed (`-previewApp`/`-previewOnboarding`/`-previewAuth` skip networking entirely).

### Auth
Supabase Auth. Three methods in `AuthView`: **Apple** (native id-token), **Google** (native GoogleSignIn id-token), and **Email OTP** (`EmailAuthSheet`). No invite gate. On signup, a DB trigger (`handle_new_user`, on `auth.users`) auto-creates a `profiles` row (`onboarding_complete = false`), pre-filling `name` from the OAuth `full_name` when present. New users route to onboarding; returning users (`onboarding_complete = true`) go straight to the app.

#### Email OTP + Resend (branded verification email)
Email sign-in uses `signInWithOTP(email:, shouldCreateUser: true)` → `verifyOTP(type: .email)`. Verifying a code for a new email **creates the account** on the spot. Requirements:
- **Email OTP length must be 6** (Auth → Providers → Email). The app's `EmailAuthSheet` caps input at 6 digits — an 8-digit code cannot be entered.
- Delivery is handled by a **Send Email Hook** (Auth → Hooks, type HTTPS) pointing at the edge function `send-auth-email` (`supabase/functions/send-auth-email/index.ts`, deployed with `verify_jwt = false`). It verifies the Standard-Webhooks signature, then sends a branded Circle email (Cormorant Garamond + Hanken Grotesk, app palette) via the **Resend** API. While the hook is enabled, Supabase's built-in email templates are bypassed.
- **Edge-function secrets** (set in dashboard → Edge Functions → Secrets; never in code):
  `RESEND_API_KEY`, `SEND_EMAIL_HOOK_SECRET` (the `v1,whsec_…` shown when the hook is created), `AUTH_EMAIL_FROM` (e.g. `Circle <noreply@insyd.in>` — the domain must be verified in Resend).
- **Raise the email rate limit** (Auth → Rate Limits) off the 2/hour default — that cap protected Supabase's shared email, which the Resend hook no longer uses.
- Frontend auth errors are funneled through `AppState.friendlyAuthError(_:)`, which maps everything to short human messages (and stays silent on user cancellation) — raw error codes/domains never reach the UI.

#### Push notifications (APNs via Resend-style hook)
Match + new-message pushes. Wired but **dormant until Apple setup is done**:
- **Client:** `CircleApp.AppDelegate` captures the APNs token → `AppState.registerPushToken` → `device_tokens` table (`registerDeviceToken`). Permission is requested when the user reaches the app / toggles "New introductions" on (`syncPushRegistration`). Token is removed on logout.
- **DB:** `device_tokens (token pk, user_id, platform, updated_at)` with own-row RLS.
- **Edge function `push-notify`** (`supabase/functions/push-notify/index.ts`, `verify_jwt=false`): invoked by **Database Webhooks** on INSERT into `messages` and `matches`; resolves recipient(s), looks up their tokens, sends APNs with an ES256-signed auth token. Authenticated by an `x-webhook-secret` header.
- **Apple setup required (user):** in Xcode add the **Push Notifications** capability (adds `aps-environment`); in the Apple Developer portal create an **APNs Auth Key (.p8)** and note its Key ID + your Team ID.
- **Edge-function secrets:** `PUSH_WEBHOOK_SECRET`, `APNS_KEY_P8` (the .p8 contents), `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID=com.circlein.app`, `APNS_ENV` (`sandbox` for dev/TestFlight, `production` for App Store).
- **Webhooks (dashboard):** Database → Webhooks → two INSERT webhooks (on `messages`, on `matches`) → HTTP POST to `…/functions/v1/push-notify` with header `x-webhook-secret: <PUSH_WEBHOOK_SECRET>`.

### Tables (schema `public`, all with RLS)
| Table | Purpose | Key columns / rules |
|---|---|---|
| `interests` | topic vocabulary (22 seeded) | `slug` PK (e.g. `hiking`), `label` (e.g. `Hiking`), `sort_order`. Read-only to clients. |
| `prompts` | prompt vocabulary (22 seeded) | `id` PK (e.g. `sunday`), `question`, `sort_order`, `active`. Read-only to clients. |
| `profiles` | 1:1 with `auth.users` | `id` PK→auth.users, `name`, `birthdate` (date), `pronouns`, `city`, `work`, `bio`, `onboarding_complete`, `paused`, `notifications`. All signed-in users can SELECT; only owner can INSERT/UPDATE. |
| `profile_photos` | photo slots | `profile_id`, `position` 0–5 (unique per profile), `storage_path` (`{uid}/{uuid}.jpg` in bucket `photos`). Viewable by signed-in; owner-managed. |
| `profile_interests` | user ↔ interest | PK (`profile_id`,`interest`→interests.slug). Viewable by signed-in; owner insert/delete. |
| `profile_prompts` | user ↔ prompt + answer | PK (`profile_id`,`prompt_id`), `answer` (≤600), `position` 0–2 (**hard cap 3**). Viewable by signed-in; owner-managed. |
| `interactions` | one like/pass per (actor,target) | PK (`actor_id`,`target_id`), `action in ('like','pass')`. **No direct writes** — only via `act_on_profile` RPC. Users can read their own outbound rows. |
| `matches` | mutual like | `user_a < user_b` (canonical order), unique pair. Auto-created by RPC. Participants-only read. |
| `messages` | chat within a match | `match_id`, `sender_id`, `body` (≤2000), `read_at`. Participants read; sender must be participant; only the recipient can mark read. **Realtime enabled** (also on `matches`). |

### RPCs (the client API — `supabase.rpc(...)`, authenticated-only; anon fully revoked)
- `get_discovery_feed(p_topics text[], p_limit int)` → the Explore feed. Complete, unpaused profiles the caller hasn't interacted with; if `p_topics` is null/empty returns everyone, else only people sharing ≥1 of those interest slugs. Ranked by `shared_count` (interests shared with caller) desc, newest first. Max 50.
- `act_on_profile(p_target uuid, p_action 'like'|'pass')` → records the interaction; **enforces the 5 likes/day cap server-side** (raises `daily like limit reached`); on mutual like auto-creates the match. Returns `{ matched, match_id, likes_remaining }`.
- `likes_remaining()` → int, resets at UTC midnight (count of today's likes vs 5).
- `get_likers()` → people who liked me that I haven't answered (the Invites tab).

Everything else is plain PostgREST table access under RLS: read `interests`/`prompts` for vocab, upsert own `profiles` row + `profile_interests` + `profile_prompts`, select `matches`, select/insert `messages` (+ realtime subscription for live chat), select other users' `profiles`/`profile_photos`/`profile_prompts`/`profile_interests` for the profile detail view.

### Storage
Bucket **`photos`** (private, 5MB limit, jpeg/png/webp). Path convention **`{auth.uid()}/{uuid}.jpg`** — policies allow any signed-in user to read, and only the owner to write/delete inside their own folder. Client uploads the already-downscaled JPEG from `AppState.setPhoto`, then inserts a `profile_photos` row with the path; render via signed/authenticated URL.

### Match/likes semantics
- Like → `act_on_profile('like')`; costs 1 of 5 daily; if target already liked you → match + both see it (matches realtime).
- Pass → free, unlimited; removes them from your feed permanently (row in `interactions`).
- The client's optimistic "conversation created on like" behavior should change to: **conversation appears on MATCH** (mutual like) — the `matches` row is the conversation; messages hang off `match_id`.

### iOS integration (next task)
- Add **supabase-swift** SPM package; init client with the project URL + publishable key (dashboard → Settings → API Keys).
- Replace: `onInviteChanged` → Google/Apple `signInWithOAuth`; `completeOnboarding` → profile upsert + `onboarding_complete = true`; `exploreCandidates` → `get_discovery_feed`; `likeMember`/`passMember` → `act_on_profile`; `likesRemaining` → `likes_remaining()`; chat → `messages` table + realtime channel; photos → storage upload in `setPhoto`.
- The client vocab (`CTData.interests` labels ↔ `interests.slug/label`, `CTData.prompts` ids ↔ `prompts.id`) is seeded **identically** in the DB; fetch from DB going forward.

### Data model mapping notes
- `Member.portrait` (PortraitSeed gradient) → other users' `profile_photos` (real URLs) once profiles are real.
- `UserProfile.photos` (`[Data?]`) → upload to bucket + `profile_photos` rows; keep `Data` as a local cache only.
- `UserProfile.dobD/M/Y` strings → `profiles.birthdate` (date). Age derived client-side.
- Interest **slugs** are the DB keys (`hiking`), labels (`Hiking`) are display — the client currently uses labels as ids; map label→slug when writing `profile_interests` (or match on `label`).

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
- `ProfilePhoto(data:placeholder:)` — renders an uploaded photo (`Data` → `UIImage`) scaled-to-fill, or a `@ViewBuilder` placeholder when empty. Used by `PhotoSlot`, onboarding Review thumbnail, and the Profile portrait card. Always wrap it in a sized + clipped container (it fills).
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
- **OnboardingView** — 10 steps (welcome, name, birthday DD/MM/YYYY, **photos (real upload)**, about [pronouns + seeking], city, work, **prompts (PromptComposer: pick up to 3 from the list, answer each inline)**, interests [≥3], review). The photos step uses `PhotoGrid` → `PhotoSlot` (SwiftUI `PhotosPicker`): tap a frame to pick/replace; ✕ removes. `PhotoSlot` resets its `pickerItem` to `nil` after each pick/remove so the picker reopens clean and re-picking the same image still fires. `PhotoGrid` and `PromptComposer` are reused in EditProfileView.
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
4. **App icon (`AppIcon.appiconset`) still shows the old "Coterie" art**, and `circle-logo.imageset` is now **unused** (LogoMark is serif text). Provide a new **Circle** icon (single opaque 1024px, no alpha) and drop or replace the imageset.
5. **Bundle id is `com.circlein.app`.** The Xcode project, target, and source folder are all named `Circle`; the module name is `Circle`.
6. Copy throughout still leans editorial/curated ("The Gallery", "Curated for you", "Introduced by Circle" → already partly updated). Audit for friend-tone.

---

## 12. Build / run / test

- **Open:** `Circle.xcodeproj` in Xcode (iOS 26 SDK).
- **Build (CLI):**
  ```
  xcodebuild -project Circle.xcodeproj -scheme Circle \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath /tmp/circle-dd build
  ```
- **Run a preview state on the simulator** (DEBUG launch args), e.g. land on Explore:
  ```
  xcrun simctl launch booted com.circlein.app -previewApp -previewTab today
  ```
  Add `-previewDark` to force dark, or `-previewOnboarding -previewStep N`.
- **Source of truth for correctness is `xcodebuild`.** SourceKit/IDE may show false "Cannot find type 'X' in scope" cross-file errors that are not real — trust a clean `xcodebuild`.
- **Adding files:** drop them in the right folder; synchronized groups auto-include them (no pbxproj edits).

---

## 13. Next steps (backend is DONE — §8; what remains is iOS integration)

1. **Configure auth providers** in the Supabase dashboard (Google + Apple; add the iOS bundle id / redirect URL). No code needed server-side.
2. **Add supabase-swift** to the Xcode project and create a small `SupabaseService` (client init with project URL + publishable key).
3. **Replace the invite gate** (`InviteView`/`onInviteChanged`) with Sign in with Google/Apple; route by `profiles.onboarding_complete` (returning users skip onboarding).
4. **Wire onboarding/edit** → `profiles` upsert, `profile_interests`, `profile_prompts`; photo upload to the `photos` bucket inside `AppState.setPhoto` + `profile_photos` rows.
5. **Wire Explore** → `get_discovery_feed(topics)`; like/pass → `act_on_profile`; likes pill → `likes_remaining()`. Conversation should now appear on **match** (mutual like), not on like.
6. **Wire Messages/Chat** → `matches` + `messages` with a realtime subscription (drop `replyPool` simulation). Invites tab → `get_likers()`.
7. Push notifications for matches/messages (APNs; `profiles.notifications` toggle already exists).
8. Resolve the dating-era leftovers in §11 with product.

> The DB seeds `interests` and `prompts` **identically to `CTData`** — fetch vocab from the DB going forward; note interests use **slugs** as keys (client labels map to `interests.label`).
