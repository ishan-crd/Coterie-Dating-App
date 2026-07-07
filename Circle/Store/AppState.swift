//
//  AppState.swift
//  Circle
//
//  The single source of truth for session, navigation and data. Backed by
//  Supabase (auth, profiles, discovery, matches, messages, storage) via
//  SupabaseService. UserDefaults keeps only lightweight preferences.
//

import SwiftUI
import Combine
import UIKit
import UserNotifications
import AuthenticationServices
import Supabase

@MainActor
final class AppState: ObservableObject {

    // MARK: Navigation
    @Published var stage: AppStage = .loading
    @Published var tab: MainTab = .today

    // MARK: Auth
    @Published var authBusy = false
    @Published var authError: String?
    var appleNonce: String?

    // MARK: Onboarding
    @Published var onboardingStep = 0

    // MARK: The signed-in user
    @Published var profile = UserProfile()

    // MARK: Vocabularies (fetched from backend; CTData as fallback)
    @Published var interestOptions: [(slug: String, label: String)] = []
    @Published var promptOptions: [(id: String, q: String)] = CTData.prompts

    // MARK: Explore (friend discovery)
    @Published var exploreTopics: Set<String> = []      // labels
    @Published var feed: [Member] = []
    @Published var feedLoading = false
    @Published var passedIDs: Set<String> = []
    @Published var likedIDs: Set<String> = []
    @Published var likesRemaining = 5
    /// Set when a like creates a mutual match — drives the "It's a match" moment.
    @Published var matchedMember: Member?

    /// Everyone we've seen this session (feed, likers, matches), by id.
    @Published var knownMembers: [String: Member] = [:]
    /// Downloaded photos per member id (first photo onwards).
    @Published var memberPhotos: [String: [Data]] = [:]

    // MARK: Likers ("Invites" tab)
    @Published var invitations: [Invitation] = []

    // MARK: Conversations (built from matches + messages)
    @Published var conversations: [String: Conversation] = [:]   // key: other user id
    @Published var conversationOrder: [String] = []
    private var matchIDs: [String: UUID] = [:]                    // other user id → match id

    // MARK: Sheets
    @Published var activeSheet: ActiveSheet?

    // MARK: Preferences (persisted locally)
    @Published var notifications = true {
        didSet { persistSettings(); if notifications && !oldValue { syncPushRegistration() } }
    }
    @Published var paused = false { didSet { persistSettings() } }
    @Published var appearance: AppearanceMode = .system { didSet { persistSettings() } }
    let mood: PortraitMood = .studio

    /// Photo slots changed locally since the last server sync.
    private var dirtyPhotoSlots: Set<Int> = []
    private var realtimeTask: Task<Void, Never>?
    private var isPreview = false

    // MARK: - Lifecycle

    init() {
        loadSettings()
        AppDelegate.appState = self
        #if DEBUG
        if applyPreviewLaunchArguments() { isPreview = true; return }
        #endif
        Task { await bootstrap() }
    }

    /// Decide the entry stage from the current auth session.
    private func bootstrap() async {
        let session = SupabaseService.auth.currentSession
        if let session, !session.isExpired {
            await enterSignedIn()
        } else if session != nil {
            // Stored session exists but is expired — try a refresh before giving up.
            if (try? await SupabaseService.auth.refreshSession()) != nil {
                await enterSignedIn()
            } else {
                stage = .auth
            }
        } else {
            stage = .auth
        }
    }

    // MARK: - Auth

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            authError = friendlyAuthError(error)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                authError = "Apple sign-in returned no token."
                return
            }
            let nonce = appleNonce
            runAuth {
                try await SupabaseService.signInWithApple(idToken: token, nonce: nonce)
            }
        }
    }

    func signInWithGoogle() {
        runAuth {
            let tokens = try await GoogleAuth.signIn()
            try await SupabaseService.signInWithGoogle(idToken: tokens.idToken,
                                                       accessToken: tokens.accessToken)
        }
    }

    func sendEmailCode(email: String, onSent: @escaping () -> Void) {
        authError = nil
        authBusy = true
        Task {
            do {
                try await SupabaseService.sendEmailOTP(email)
                authBusy = false
                onSent()
            } catch {
                authBusy = false
                if let msg = friendlyAuthError(error) { authError = msg }
            }
        }
    }

    func verifyEmailCode(email: String, code: String, onDone: @escaping () -> Void) {
        authError = nil
        authBusy = true
        Task {
            do {
                try await SupabaseService.verifyEmailOTP(email, code: code)
                authBusy = false
                onDone()
                await enterSignedIn()
            } catch {
                authBusy = false
                if let msg = friendlyAuthError(error) { authError = msg }
            }
        }
    }

    private func runAuth(_ op: @escaping () async throws -> Void) {
        authError = nil
        authBusy = true
        Task {
            do {
                try await op()
                authBusy = false
                await enterSignedIn()
            } catch {
                authBusy = false
                if let msg = friendlyAuthError(error) { authError = msg }
            }
        }
    }

    /// Maps any auth error to a short, human message. Returns `nil` when the
    /// user simply cancelled (nothing worth showing). Never surfaces raw
    /// technical codes / domains to the UI.
    private func friendlyAuthError(_ error: Error) -> String? {
        let ns = error as NSError

        // User-initiated cancellations → stay silent.
        if (error as? ASAuthorizationError)?.code == .canceled { return nil }
        let text = error.localizedDescription.lowercased()
        if text.contains("cancel") { return nil }

        func has(_ needles: String...) -> Bool { needles.contains { text.contains($0) } }

        // No connectivity.
        if ns.domain == NSURLErrorDomain || has("offline", "internet", "network connection", "connection appears") {
            return "You appear to be offline. Check your connection and try again."
        }
        // Wrong / expired verification code.
        if has("invalid", "incorrect", "expired", "token has expired", "otp") {
            return "That code is invalid or has expired. Request a new one."
        }
        // Per-email resend cooldown ("...you can only request this after N seconds").
        if has("security purposes", "only request", "seconds") {
            return "Please wait a moment before requesting another code."
        }
        // Too many requests.
        if has("rate limit", "too many", "429") {
            return "Too many attempts. Please wait a moment and try again."
        }
        // Bad email address.
        if has("email") && has("invalid", "valid") {
            return "That email address doesn’t look right."
        }
        // Apple authorization failures (e.g. not signed into iCloud on device).
        if error is ASAuthorizationError || ns.domain.contains("AuthenticationServices") {
            return "Apple Sign-In couldn’t be completed. Please try again."
        }

        // Anything else — a single, calm fallback.
        return "Something went wrong. Please try again."
    }

    /// After any successful sign-in: load vocab + profile, then route.
    private func enterSignedIn() async {
        await loadVocabularies()
        do {
            let row = try await SupabaseService.fetchOwnProfile()
            // A returning, previously-deactivated user: clear the marker and
            // send them through onboarding fresh (their data was wiped).
            if !isPreview, let row, row.deleted_at != nil {
                try? await SupabaseService.reactivateAccount()
            }
            if let row, row.onboarding_complete {
                apply(row)
                await loadOwnExtras()
                withAnimation(.easeOut(duration: 0.5)) { stage = .app; tab = .today }
                await loadSignedInData()
                uploadPendingPushToken()
                syncPushRegistration()
            } else {
                if let row { apply(row) }
                onboardingStep = 0
                withAnimation(.easeOut(duration: 0.5)) { stage = .onboarding }
            }
        } catch {
            authError = friendlyAuthError(error)
            stage = .auth
        }
    }

    // MARK: - Server → local profile mapping

    private func apply(_ row: ProfileRow) {
        profile.name = row.name
        profile.pronouns = row.pronouns ?? ""
        profile.city = row.city ?? ""
        profile.work = row.work ?? ""
        profile.bio = row.bio
        if let b = row.birthdate, b.count == 10 {
            let parts = b.split(separator: "-")
            if parts.count == 3 {
                profile.dobY = String(parts[0]); profile.dobM = String(parts[1]); profile.dobD = String(parts[2])
            }
        }
        paused = row.paused
        notifications = row.notifications
    }

    /// Interests, prompts and photos for the signed-in user.
    private func loadOwnExtras() async {
        guard let uid = SupabaseService.userID else { return }
        if let slugs = try? await SupabaseService.fetchInterestSlugs(of: uid) {
            profile.interests = slugs.compactMap { s in interestOptions.first { $0.slug == s }?.label }
        }
        if let rows = try? await SupabaseService.fetchPromptRows(of: uid) {
            profile.prompts = rows.map { PromptResponse(promptId: $0.prompt_id, answer: $0.answer) }
        }
        if let photoRows = try? await SupabaseService.fetchPhotoRows(of: uid) {
            var slots: [Data?] = Array(repeating: nil, count: 6)
            for row in photoRows where row.position < 6 {
                slots[row.position] = try? await SupabaseService.downloadPhoto(path: row.storage_path)
            }
            profile.photos = slots
            dirtyPhotoSlots = []
        }
    }

    private func loadVocabularies() async {
        if let rows = try? await SupabaseService.fetchInterests(), !rows.isEmpty {
            interestOptions = rows.map { ($0.slug, $0.label) }
        } else {
            interestOptions = CTData.interests.map { (slugify($0), $0) }
        }
        if let rows = try? await SupabaseService.fetchPrompts(), !rows.isEmpty {
            promptOptions = rows.map { ($0.id, $0.question) }
        }
    }

    private func slugify(_ label: String) -> String {
        label.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    var interestLabels: [String] { interestOptions.map(\.label) }

    private func slugs(forLabels labels: [String]) -> [String] {
        labels.compactMap { l in interestOptions.first { $0.label == l }?.slug }
    }

    // MARK: - Signed-in data (feed, likers, matches)

    private func loadSignedInData() async {
        await refreshLikes()
        await refreshFeed()
        await refreshLikers()
        await refreshConversations()
        startRealtime()
    }

    func refreshLikes() async {
        if let n = try? await SupabaseService.likesRemaining() { likesRemaining = n }
    }

    func refreshFeed() async {
        feedLoading = true
        defer { feedLoading = false }
        let topicSlugs = exploreTopics.isEmpty ? nil : slugs(forLabels: Array(exploreTopics))
        guard let rows = try? await SupabaseService.discoveryFeed(topics: topicSlugs) else { return }
        var members: [Member] = []
        for row in rows {
            let member = await materialize(rowID: row.id, name: row.name, birthdate: row.birthdate,
                                           city: row.city, work: row.work, bio: row.bio)
            members.append(member)
        }
        feed = members
    }

    /// Build (and cache) a Member from profile data, loading interests, prompts
    /// and photos on the way.
    private func materialize(rowID: UUID, name: String, birthdate: String?,
                             city: String?, work: String?, bio: String) async -> Member {
        let id = rowID.uuidString.lowercased()
        let slugs = (try? await SupabaseService.fetchInterestSlugs(of: rowID)) ?? []
        let labels = slugs.compactMap { s in interestOptions.first { $0.slug == s }?.label }
        let promptRows = (try? await SupabaseService.fetchPromptRows(of: rowID)) ?? []
        let prompts = promptRows.map { row in
            PromptAnswer(q: promptOptions.first { $0.id == row.prompt_id }?.q ?? row.prompt_id,
                         a: row.answer)
        }
        let shared = labels.filter { profile.interests.contains($0) }
        let why = shared.isEmpty
            ? "New to your circle."
            : "You're both into \(shared.prefix(3).joined(separator: ", "))."

        let member = Member(
            id: id,
            name: name,
            age: Self.age(fromISO: birthdate) ?? 0,
            city: city ?? "",
            role: work ?? "",
            portrait: Self.portraitSeed(for: id),
            bio: bio,
            why: why,
            prompts: prompts,
            interests: labels
        )
        knownMembers[id] = member

        if memberPhotos[id] == nil,
           let photoRows = try? await SupabaseService.fetchPhotoRows(of: rowID) {
            var datas: [Data] = []
            for row in photoRows.prefix(3) {
                if let d = try? await SupabaseService.downloadPhoto(path: row.storage_path) {
                    datas.append(d)
                }
            }
            memberPhotos[id] = datas
        }
        return member
    }

    private static func age(fromISO iso: String?) -> Int? {
        guard let iso, iso.count == 10 else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let birth = f.date(from: iso) else { return nil }
        return Calendar.current.dateComponents([.year], from: birth, to: Date()).year
    }

    /// Deterministic portrait-gradient seed for members without photos.
    static func portraitSeed(for id: String) -> PortraitSeed {
        var hash: UInt64 = 5381
        for b in id.utf8 { hash = hash &* 33 &+ UInt64(b) }
        return PortraitSeed(lx: Double(20 + hash % 60), ly: Double(12 + (hash / 100) % 70))
    }

    func member(_ id: String) -> Member? {
        knownMembers[id] ?? CTData.member(id)
    }

    func refreshLikers() async {
        guard let rows = try? await SupabaseService.likers() else { return }
        var invites: [Invitation] = []
        for row in rows {
            let id = row.id.uuidString.lowercased()
            if knownMembers[id] == nil, let p = try? await SupabaseService.fetchProfile(row.id) {
                _ = await materialize(rowID: p.id, name: p.name, birthdate: p.birthdate,
                                      city: p.city, work: p.work, bio: p.bio)
            }
            // A note grounded in what you actually have in common.
            let shared = knownMembers[id].map { sharedInterests($0) } ?? []
            let note: String
            switch shared.count {
            case 0:  note = "Liked your profile."
            case 1:  note = "You both like \(shared[0])."
            default: note = "You both like \(shared.prefix(2).joined(separator: " & "))."
            }
            invites.append(Invitation(id: id, note: note, time: ""))
        }
        invitations = invites
    }

    // MARK: - Explore actions

    var exploreCandidates: [Member] {
        feed.filter { !passedIDs.contains($0.id) && !likedIDs.contains($0.id) }
    }

    var myTopics: [String] { profile.interests }

    func toggleTopic(_ topic: String) {
        if exploreTopics.contains(topic) { exploreTopics.remove(topic) }
        else { exploreTopics.insert(topic) }
        Task { await refreshFeed() }
    }

    func clearTopics() {
        exploreTopics.removeAll()
        Task { await refreshFeed() }
    }

    func sharedInterests(_ member: Member) -> [String] {
        member.interests.filter { profile.interests.contains($0) }
    }

    func passMember(_ id: String) {
        withAnimation(.easeOut(duration: 0.28)) { _ = passedIDs.insert(id) }
        guard !isPreview, let uuid = UUID(uuidString: id) else { return }
        Task { _ = try? await SupabaseService.actOnProfile(uuid, action: "pass") }
    }

    func likeMember(_ id: String) {
        guard likesRemaining > 0, !likedIDs.contains(id) else { return }
        withAnimation(.easeOut(duration: 0.28)) { _ = likedIDs.insert(id) }
        likesRemaining -= 1
        guard !isPreview, let uuid = UUID(uuidString: id) else { return }
        Task {
            if let result = try? await SupabaseService.actOnProfile(uuid, action: "like") {
                likesRemaining = result.likes_remaining
                if result.matched {
                    await refreshConversations()
                    // Surface the moment instead of silently jumping to chat.
                    if let m = member(id) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            matchedMember = m
                        }
                    }
                }
            }
        }
    }

    /// Open the conversation with the just-matched person, dismissing the moment.
    func messageMatch() {
        guard let id = matchedMember?.id else { return }
        matchedMember = nil
        activeSheet = .chat(id)
    }

    func dismissMatch() {
        withAnimation(.easeOut(duration: 0.3)) { matchedMember = nil }
    }

    func resetDeck() {
        Task { await refreshFeed() }
        withAnimation { passedIDs.removeAll() }
    }

    // MARK: - Onboarding

    let steps: [OnboardingStep] = OnboardingStep.allCases

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .review: return true
        case .name:      return profile.name.trimmingCharacters(in: .whitespaces).count >= 2
        case .birthday:  return profile.isValidBirthday
        case .photos:    return profile.filledPhotoCount >= 2
        case .about:     return !profile.pronouns.isEmpty && !profile.seeking.isEmpty
        case .city:      return !profile.city.trimmingCharacters(in: .whitespaces).isEmpty
        case .work:      return !profile.work.trimmingCharacters(in: .whitespaces).isEmpty
        case .prompt:    return !profile.prompts.isEmpty &&
                                profile.prompts.allSatisfy { !$0.answer.trimmingCharacters(in: .whitespaces).isEmpty }
        case .interests: return profile.interests.count >= 3
        }
    }

    func advanceOnboarding() {
        let current = steps[onboardingStep]
        guard canAdvance(from: current) else { return }
        if onboardingStep >= steps.count - 1 {
            completeOnboarding()
        } else {
            withAnimation(.easeOut(duration: 0.45)) { onboardingStep += 1 }
        }
    }

    func backOnboarding() {
        guard onboardingStep > 0 else { return }
        withAnimation(.easeOut(duration: 0.45)) { onboardingStep -= 1 }
    }

    private func completeOnboarding() {
        Persistence.saveProfile(profile)
        withAnimation(.easeOut(duration: 0.5)) { stage = .app; tab = .today }
        guard !isPreview else { return }
        Task {
            await pushProfile(markComplete: true)
            await loadSignedInData()
            uploadPendingPushToken()
            syncPushRegistration()
        }
    }

    func saveProfileEdits() {
        Persistence.saveProfile(profile)
        guard !isPreview else { return }
        Task { await pushProfile(markComplete: true) }
    }

    /// Push the whole local profile (fields, interests, prompts, dirty photos).
    private func pushProfile(markComplete: Bool) async {
        guard let uid = SupabaseService.userID else { return }
        let birthdate: String? = (profile.dobY.count == 4 && !profile.dobM.isEmpty && !profile.dobD.isEmpty)
            ? String(format: "%@-%02d-%02d", profile.dobY, Int(profile.dobM) ?? 1, Int(profile.dobD) ?? 1)
            : nil
        let row = ProfileRow(
            id: uid,
            name: profile.name,
            birthdate: birthdate,
            pronouns: profile.pronouns.isEmpty ? nil : profile.pronouns,
            city: profile.city.isEmpty ? nil : profile.city,
            work: profile.work.isEmpty ? nil : profile.work,
            bio: profile.bio.trimmingCharacters(in: .whitespacesAndNewlines),
            onboarding_complete: markComplete,
            paused: paused,
            notifications: notifications
        )
        try? await SupabaseService.upsertOwnProfile(row)
        try? await SupabaseService.replaceOwnInterests(slugs(forLabels: profile.interests))
        try? await SupabaseService.replaceOwnPrompts(
            profile.prompts.map { ($0.promptId, $0.answer) }
        )
        for slot in dirtyPhotoSlots.sorted() {
            if let data = profile.photos[slot] {
                _ = try? await SupabaseService.uploadPhoto(data, position: slot)
            } else {
                try? await SupabaseService.deletePhoto(position: slot)
            }
        }
        dirtyPhotoSlots = []
    }

    // MARK: - Photos (local slot + dirty tracking; upload happens on save)

    func setPhoto(_ index: Int, _ data: Data) {
        guard profile.photos.indices.contains(index) else { return }
        profile.photos[index] = Self.downscaledJPEG(data) ?? data
        dirtyPhotoSlots.insert(index)
    }

    func removePhoto(_ index: Int) {
        guard profile.photos.indices.contains(index) else { return }
        profile.photos[index] = nil
        dirtyPhotoSlots.insert(index)
    }

    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1080,
                               quality: CGFloat = 0.72) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    func toggleInterest(_ tag: String) {
        if let i = profile.interests.firstIndex(of: tag) {
            profile.interests.remove(at: i)
        } else {
            profile.interests.append(tag)
        }
    }

    // MARK: Prompts

    static let maxPrompts = 3

    var availablePrompts: [(id: String, q: String)] {
        promptOptions.filter { p in !profile.prompts.contains { $0.promptId == p.id } }
    }

    func addPrompt(_ promptId: String) {
        guard profile.prompts.count < Self.maxPrompts,
              !profile.prompts.contains(where: { $0.promptId == promptId }) else { return }
        profile.prompts.append(PromptResponse(promptId: promptId))
    }

    func removePrompt(_ id: UUID) {
        profile.prompts.removeAll { $0.id == id }
    }

    func promptAnswerBind(_ id: UUID) -> Binding<String> {
        Binding(get: { self.profile.prompts.first { $0.id == id }?.answer ?? "" },
                set: { v in
                    if let i = self.profile.prompts.firstIndex(where: { $0.id == id }) {
                        self.profile.prompts[i].answer = v
                    }
                })
    }

    /// Question text for a prompt id (backend vocab, CTData fallback).
    func promptQuestion(_ id: String) -> String? {
        promptOptions.first { $0.id == id }?.q ?? CTData.promptText(id)
    }

    // MARK: - Conversations (matches + messages)

    func refreshConversations() async {
        guard let uid = SupabaseService.userID,
              let matches = try? await SupabaseService.fetchMatches() else { return }
        var convos: [String: Conversation] = [:]
        var order: [String] = []
        var ids: [String: UUID] = [:]

        for match in matches {
            let otherID = match.user_a == uid ? match.user_b : match.user_a
            let key = otherID.uuidString.lowercased()
            if knownMembers[key] == nil, let p = try? await SupabaseService.fetchProfile(otherID) {
                _ = await materialize(rowID: p.id, name: p.name, birthdate: p.birthdate,
                                      city: p.city, work: p.work, bio: p.bio)
            }
            let rows = (try? await SupabaseService.fetchMessages(matchID: match.id)) ?? []
            let messages = rows.map { row in
                ChatMessage(id: row.id, fromMe: row.sender_id == uid, text: row.body)
            }
            let unread = rows.contains { $0.sender_id != uid && $0.read_at == nil }
            convos[key] = Conversation(
                id: key,
                preview: rows.last?.body ?? "You connected — say hello.",
                time: Self.displayTime(rows.last?.created_at ?? match.created_at),
                unread: unread,
                messages: messages
            )
            ids[key] = match.id
            order.append(key)
        }
        conversations = convos
        conversationOrder = order
        matchIDs = ids
    }

    private static func displayTime(_ iso: String) -> String {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ", "yyyy-MM-dd'T'HH:mm:ssZ"]
        for fmt in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            if let date = f.date(from: iso) {
                let out = DateFormatter()
                out.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d MMM"
                return out.string(from: date)
            }
        }
        return ""
    }

    func openProfile(_ id: String) { activeSheet = .profile(id) }

    func openChat(with id: String, seeding: Bool = false) {
        conversations[id]?.unread = false
        tab = .messages
        activeSheet = .chat(id)
    }

    func closeSheet() { activeSheet = nil }

    func send(_ text: String, to id: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Optimistic append
        var convo = conversations[id] ?? Conversation(id: id, preview: "", time: "now",
                                                       unread: false, messages: [])
        convo.messages.append(ChatMessage(fromMe: true, text: trimmed))
        convo.preview = trimmed
        convo.time = "now"
        conversations[id] = convo
        if !conversationOrder.contains(id) { conversationOrder.insert(id, at: 0) }

        guard !isPreview, let matchID = matchIDs[id] else { return }
        Task { _ = try? await SupabaseService.sendMessage(matchID: matchID, body: trimmed) }
    }

    // MARK: - Realtime (incoming messages)

    private func startRealtime() {
        guard !isPreview, realtimeTask == nil, let uid = SupabaseService.userID else { return }
        realtimeTask = Task { [weak self] in
            let channel = SupabaseService.client.channel("messages-inserts")
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
            await channel.subscribe()
            for await action in inserts {
                guard let self else { break }
                if let row = try? action.decodeRecord(as: MessageRow.self, decoder: JSONDecoder()),
                   row.sender_id != uid {
                    await self.receiveRemote(row)
                }
            }
        }
    }

    private func receiveRemote(_ row: MessageRow) async {
        guard let key = matchIDs.first(where: { $0.value == row.match_id })?.key else {
            await refreshConversations()
            return
        }
        // Ignore if we already have it
        if conversations[key]?.messages.contains(where: { $0.id == row.id }) == true { return }
        var convo = conversations[key]
        convo?.messages.append(ChatMessage(id: row.id, fromMe: false, text: row.body))
        convo?.preview = row.body
        convo?.time = "now"
        convo?.unread = activeSheet?.id != "chat-\(key)"
        if let convo { conversations[key] = convo }
    }

    // MARK: - Account

    /// Deactivate (soft-delete) the account: wipe onboarding data server-side,
    /// keep the auth user + row (Apple token is one-shot), then sign out. A
    /// later sign-in reactivates and re-onboards. See `deactivateAccount`.
    func deleteAccount() {
        Task {
            if !isPreview {
                try? await SupabaseService.deleteAllOwnPhotos()
                try? await SupabaseService.deactivateAccount()
            }
            logout()
        }
    }

    func logout() {
        realtimeTask?.cancel()
        realtimeTask = nil
        let token = pendingPushToken
        Task {
            if let token { await SupabaseService.removeDeviceToken(token) }
            await SupabaseService.signOut()
        }
        Persistence.clear()
        profile = UserProfile()
        onboardingStep = 0
        feed = []
        knownMembers = [:]
        memberPhotos = [:]
        passedIDs = []
        likedIDs = []
        invitations = []
        conversations = [:]
        conversationOrder = []
        matchIDs = [:]
        exploreTopics = []
        activeSheet = nil
        tab = .today
        withAnimation(.easeOut(duration: 0.4)) { stage = .auth }
    }

    // MARK: - Push notifications

    /// The most recent APNs token, held until the user is authenticated so it
    /// can be uploaded once we know their id.
    private var pendingPushToken: String?

    /// Ask for permission (only if notifications are enabled) and register with
    /// APNs. The token arrives asynchronously via the app delegate.
    func syncPushRegistration() {
        guard notifications, !isPreview else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Called by the app delegate with the device's APNs token (hex string).
    func registerPushToken(_ token: String) {
        pendingPushToken = token
        uploadPendingPushToken()
    }

    private func uploadPendingPushToken() {
        guard !isPreview, let token = pendingPushToken, SupabaseService.userID != nil else { return }
        Task { try? await SupabaseService.registerDeviceToken(token) }
    }

    private func persistSettings() {
        Persistence.saveSettings(.init(notifications: notifications, paused: paused,
                                       appearance: appearance))
    }

    private func loadSettings() {
        guard let s = Persistence.loadSettings() else { return }
        notifications = s.notifications
        paused = s.paused
        appearance = s.appearance
    }

    // MARK: - DEBUG preview seams

    #if DEBUG
    /// Returns true when a preview state was applied (skips all networking).
    private func applyPreviewLaunchArguments() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-previewDark") { appearance = .dark }
        if args.contains("-previewApp") {
            profile = .sample
            feed = CTData.members
            knownMembers = Dictionary(uniqueKeysWithValues: CTData.members.map { ($0.id, $0) })
            invitations = CTData.invitations
            seedPreviewConversations()
            stage = .app
            if let i = args.firstIndex(of: "-previewTab"), i + 1 < args.count {
                switch args[i + 1] {
                case "gallery": tab = .gallery
                case "invites": tab = .invites
                case "messages": tab = .messages
                case "profile": tab = .profile
                default: tab = .today
                }
            }
            return true
        } else if args.contains("-previewOnboarding") {
            interestOptions = CTData.interests.map { (slugify($0), $0) }
            stage = .onboarding
            onboardingStep = 0
            if let i = args.firstIndex(of: "-previewStep"), i + 1 < args.count,
               let n = Int(args[i + 1]), n >= 0, n < steps.count {
                onboardingStep = n
            }
            return true
        } else if args.contains("-previewAuth") {
            stage = .auth
            return true
        }
        return false
    }

    private func seedPreviewConversations() {
        conversations = [
            "elias": Conversation(id: "elias",
                preview: "I think you'd love the new room — come by.", time: "09:12", unread: false,
                messages: [
                    ChatMessage(fromMe: false, text: "Margot mentioned you're a Pärt person too."),
                    ChatMessage(fromMe: true, text: "Tabula Rasa got me through a hard winter."),
                    ChatMessage(fromMe: false, text: "I think you'd love the new room — come by."),
                ]),
            "ingrid": Conversation(id: "ingrid",
                preview: "The greenhouse, then. Saturday?", time: "Yesterday", unread: true,
                messages: [
                    ChatMessage(fromMe: true, text: "A scent that smells of rain on stone — I'm sold."),
                    ChatMessage(fromMe: false, text: "The greenhouse, then. Saturday?"),
                ]),
        ]
        conversationOrder = ["elias", "ingrid"]
    }
    #endif
}

// MARK: - Supporting types

enum AppStage { case loading, auth, onboarding, app }

enum MainTab: Hashable { case today, gallery, invites, messages, profile }

enum ActiveSheet: Identifiable {
    case profile(String)
    case chat(String)
    case edit

    var id: String {
        switch self {
        case .profile(let i): return "profile-\(i)"
        case .chat(let i): return "chat-\(i)"
        case .edit: return "edit"
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome, name, birthday, photos, about, city, work, prompt, interests, review
}

// MARK: - Binding helpers

extension AppState {
    func bind(_ keyPath: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(get: { self.profile[keyPath: keyPath] },
                set: { self.profile[keyPath: keyPath] = $0 })
    }

    func digitBind(_ keyPath: WritableKeyPath<UserProfile, String>, _ limit: Int) -> Binding<String> {
        Binding(get: { self.profile[keyPath: keyPath] },
                set: { self.profile[keyPath: keyPath] = String($0.filter(\.isNumber).prefix(limit)) })
    }

    /// A digit binding capped at `digits` characters and a numeric ceiling
    /// (e.g. day ≤ 31, month ≤ 12). Leading zeros are preserved while typing.
    func clampedDigitBind(_ keyPath: WritableKeyPath<UserProfile, String>,
                          digits: Int, max: Int) -> Binding<String> {
        Binding(get: { self.profile[keyPath: keyPath] },
                set: { raw in
                    var s = String(raw.filter(\.isNumber).prefix(digits))
                    if let v = Int(s), v > max { s = String(max) }
                    self.profile[keyPath: keyPath] = s
                })
    }
}
