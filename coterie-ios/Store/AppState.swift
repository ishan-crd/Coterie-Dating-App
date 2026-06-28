//
//  AppState.swift
//  coterie-ios
//
//  The single source of truth for session, navigation and persisted data.
//  Once a member has completed onboarding, their profile is stored locally and
//  they are taken straight to the app on launch — no invitation re-entry.
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: Navigation
    @Published var stage: AppStage = .invite
    @Published var tab: MainTab = .today

    // MARK: Onboarding / invitation
    @Published var inviteCode = ""
    @Published var verifying = false
    @Published var inviteError = false
    @Published var onboardingStep = 0

    /// The single invitation code accepted by this build.
    static let validInviteCode = "111111"

    // MARK: The signed-in user
    @Published var profile = UserProfile()

    // MARK: Daily introduction
    @Published var revealed = false
    @Published var dailyOutcome: DailyOutcome = .none

    // MARK: Conversations
    @Published var conversations: [String: Conversation] = [:]
    @Published var conversationOrder: [String] = []
    @Published var typing = false

    // MARK: Sheets
    @Published var activeSheet: ActiveSheet?

    // MARK: Preferences (persisted)
    @Published var notifications = true { didSet { persistSettings() } }
    @Published var paused = false { didSet { persistSettings() } }
    @Published var appearance: AppearanceMode = .light { didSet { persistSettings() } }
    /// Portrait palette — fixed to Studio; no longer user-configurable.
    let mood: PortraitMood = .studio

    private var verifyTask: Task<Void, Never>?
    private var replyTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        loadSettings()
        seedConversations()
        if let saved = Persistence.loadProfile(), saved.isComplete {
            profile = saved
            stage = .app          // returning member — skip invite & onboarding
        }
        #if DEBUG
        applyPreviewLaunchArguments()
        #endif
    }

    #if DEBUG
    /// Test seams so screens can be inspected directly during development.
    private func applyPreviewLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-previewDark") { appearance = .dark }
        if args.contains("-previewApp") {
            profile = .sample
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
        } else if args.contains("-previewOnboarding") {
            stage = .onboarding
            onboardingStep = 0
            if let i = args.firstIndex(of: "-previewStep"), i + 1 < args.count,
               let n = Int(args[i + 1]), n >= 0, n < steps.count {
                onboardingStep = n
            }
        }
    }
    #endif

    // MARK: - Invitation

    func onInviteChanged(_ raw: String) {
        let cleaned = String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
        inviteCode = cleaned
        inviteError = false
        verifyTask?.cancel()
        guard cleaned.count == 6 else { verifying = false; return }

        guard cleaned == Self.validInviteCode else {
            // Not a recognised invitation.
            verifying = false
            withAnimation { inviteError = true }
            return
        }

        verifying = true
        verifyTask = Task {
            try? await Task.sleep(nanoseconds: 950_000_000)
            guard !Task.isCancelled else { return }
            verifying = false
            // A returning member with a complete profile goes straight in.
            stage = profile.isComplete ? .app : .onboarding
            if stage == .onboarding { onboardingStep = 0 }
        }
    }

    // MARK: - Onboarding

    let steps: [OnboardingStep] = OnboardingStep.allCases

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .review: return true
        case .name:      return profile.name.trimmingCharacters(in: .whitespaces).count >= 2
        case .birthday:  return !profile.dobM.isEmpty && !profile.dobD.isEmpty && profile.dobY.count == 4
        case .photos:    return profile.filledPhotoCount >= 2
        case .about:     return !profile.pronouns.isEmpty && !profile.seeking.isEmpty
        case .city:      return !profile.city.trimmingCharacters(in: .whitespaces).isEmpty
        case .work:      return !profile.work.trimmingCharacters(in: .whitespaces).isEmpty
        case .prompt:    return !profile.promptId.isEmpty && !profile.answer.trimmingCharacters(in: .whitespaces).isEmpty
        case .interests: return profile.interests.count >= 3
        case .intention: return !profile.intention.isEmpty
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
    }

    func togglePhoto(_ index: Int) {
        if profile.photos[index] != nil {
            profile.photos[index] = nil
        } else {
            let p = CTData.photoPositions[index]
            profile.photos[index] = PortraitSeedCodable(lx: p.lx, ly: p.ly)
        }
    }

    func toggleInterest(_ tag: String) {
        if let i = profile.interests.firstIndex(of: tag) {
            profile.interests.remove(at: i)
        } else {
            profile.interests.append(tag)
        }
    }

    /// The portrait used for the user's own profile (first photo, or a default).
    var ownPortrait: PortraitSeed {
        profile.firstPhoto?.seed ?? PortraitSeed(lx: 50, ly: 16)
    }

    func saveProfileEdits() {
        Persistence.saveProfile(profile)
    }

    // MARK: - Daily introduction

    var dailyMatch: Member { CTData.member("margot")! }

    func reveal() { withAnimation(.easeOut(duration: 1.0)) { revealed = true } }

    func passDaily() { withAnimation { dailyOutcome = .passed } }

    func introduceDaily() {
        withAnimation { dailyOutcome = .introduced }
        openChat(with: "margot", seeding: true)
    }

    // MARK: - Sheets & conversations

    func openProfile(_ id: String) { activeSheet = .profile(id) }

    func openChat(with id: String, seeding: Bool = false) {
        if conversations[id] == nil {
            conversations[id] = Conversation(id: id, preview: "New introduction", time: "now",
                                             unread: false, messages: [])
            conversationOrder.insert(id, at: 0)
        } else if conversations[id]?.unread == true {
            conversations[id]?.unread = false
        }
        tab = .messages
        activeSheet = .chat(id)
    }

    func closeSheet() { activeSheet = nil }

    func send(_ text: String, to id: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var convo = conversations[id] ?? Conversation(id: id, preview: "", time: "now",
                                                       unread: false, messages: [])
        convo.messages.append(ChatMessage(fromMe: true, text: trimmed))
        convo.preview = trimmed
        convo.time = "now"
        conversations[id] = convo

        replyTask?.cancel()
        replyTask = Task {
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { typing = true }
            try? await Task.sleep(nanoseconds: 1_550_000_000)
            guard !Task.isCancelled else { return }
            let reply = CTData.replyPool.randomElement() ?? "Tell me more."
            var c = conversations[id]
            c?.messages.append(ChatMessage(fromMe: false, text: reply))
            c?.preview = reply
            conversations[id] = c
            withAnimation { typing = false }
        }
    }

    // MARK: - Account

    func logout() {
        Persistence.clear()
        verifyTask?.cancel()
        replyTask?.cancel()
        profile = UserProfile()
        inviteCode = ""
        verifying = false
        inviteError = false
        onboardingStep = 0
        revealed = false
        dailyOutcome = .none
        activeSheet = nil
        tab = .today
        seedConversations()
        withAnimation(.easeOut(duration: 0.4)) { stage = .invite }
    }

    // MARK: - Seed data & persistence

    private func seedConversations() {
        conversations = [
            "elias": Conversation(id: "elias",
                preview: "I think you’d love the new room — come by.", time: "09:12", unread: false,
                messages: [
                    ChatMessage(fromMe: false, text: "Margot mentioned you’re a Pärt person too."),
                    ChatMessage(fromMe: true, text: "Tabula Rasa got me through a hard winter."),
                    ChatMessage(fromMe: false, text: "Then you have to hear what I’m scoring now."),
                    ChatMessage(fromMe: false, text: "I think you’d love the new room — come by."),
                ]),
            "ingrid": Conversation(id: "ingrid",
                preview: "The greenhouse, then. Saturday?", time: "Yesterday", unread: true,
                messages: [
                    ChatMessage(fromMe: true, text: "A scent that smells of rain on stone — I’m sold."),
                    ChatMessage(fromMe: false, text: "It’s the truest thing I’ve ever made."),
                    ChatMessage(fromMe: false, text: "The greenhouse, then. Saturday?"),
                ]),
        ]
        conversationOrder = ["elias", "ingrid"]
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
}

// MARK: - Supporting types

enum MainTab: Hashable { case today, gallery, invites, messages, profile }

enum DailyOutcome { case none, passed, introduced }

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
    case welcome, name, birthday, photos, about, city, work, prompt, interests, intention, review
}
