//
//  SupabaseService.swift
//  coterie-ios
//
//  The single gateway to the Supabase backend: auth, profile CRUD, discovery,
//  likes, matches, messages and photo storage. AppState calls through here and
//  stays the app's only source of truth for view state.
//

import Foundation
import Supabase

// MARK: - Row / payload types (mirror the DB schema)

struct ProfileRow: Codable {
    var id: UUID
    var name: String
    var birthdate: String?        // 'yyyy-MM-dd'
    var pronouns: String?
    var city: String?
    var work: String?
    var bio: String
    var onboarding_complete: Bool
    var paused: Bool
    var notifications: Bool
}

struct InterestRow: Codable {
    var slug: String
    var label: String
    var sort_order: Int
}

struct PromptRow: Codable {
    var id: String
    var question: String
    var sort_order: Int
}

struct ProfilePhotoRow: Codable {
    var profile_id: UUID
    var position: Int
    var storage_path: String
}

struct ProfileInterestRow: Codable {
    var profile_id: UUID
    var interest: String
}

struct ProfilePromptRow: Codable {
    var profile_id: UUID
    var prompt_id: String
    var answer: String
    var position: Int
}

struct FeedRow: Codable {
    var id: UUID
    var name: String
    var birthdate: String?
    var pronouns: String?
    var city: String?
    var work: String?
    var bio: String
    var shared_count: Int
}

struct ActResult: Codable {
    var matched: Bool
    var match_id: UUID?
    var likes_remaining: Int
}

struct LikerRow: Codable {
    var id: UUID
    var name: String
    var city: String?
    var work: String?
    var liked_at: String
}

struct MatchRow: Codable {
    var id: UUID
    var user_a: UUID
    var user_b: UUID
    var created_at: String
}

struct MessageRow: Codable {
    var id: UUID
    var match_id: UUID
    var sender_id: UUID
    var body: String
    var created_at: String
    var read_at: String?
}

// MARK: - Service

enum SupabaseService {

    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://zkoweftcxxnmytnezmcf.supabase.co")!,
        supabaseKey: "sb_publishable_BynEdOOK5aRPlsTAjXwCGA_R3SD3ZoS"
    )

    static var auth: AuthClient { client.auth }

    /// The signed-in user id, or nil.
    static var userID: UUID? { auth.currentSession?.user.id }

    // MARK: Auth

    static func signInWithApple(idToken: String, nonce: String?) async throws {
        try await auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// Sign in with a Google ID token obtained natively (GoogleSignIn SDK).
    /// The token carries an AppAuth-generated nonce we can't read, so the
    /// Supabase Google provider must have "Skip nonce checks" enabled.
    static func signInWithGoogle(idToken: String, accessToken: String?) async throws {
        try await auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
    }

    static func sendPhoneOTP(_ phone: String) async throws {
        try await auth.signInWithOTP(phone: phone)
    }

    static func verifyPhoneOTP(_ phone: String, code: String) async throws {
        try await auth.verifyOTP(phone: phone, token: code, type: .sms)
    }

    static func signOut() async {
        try? await auth.signOut()
    }

    // MARK: Vocabularies

    static func fetchInterests() async throws -> [InterestRow] {
        try await client.from("interests").select()
            .order("sort_order").execute().value
    }

    static func fetchPrompts() async throws -> [PromptRow] {
        try await client.from("prompts").select()
            .eq("active", value: true).order("sort_order").execute().value
    }

    // MARK: Own profile

    static func fetchOwnProfile() async throws -> ProfileRow? {
        guard let uid = userID else { return nil }
        let rows: [ProfileRow] = try await client.from("profiles").select()
            .eq("id", value: uid).execute().value
        return rows.first
    }

    static func upsertOwnProfile(_ row: ProfileRow) async throws {
        try await client.from("profiles").upsert(row).execute()
    }

    static func replaceOwnInterests(_ slugs: [String]) async throws {
        guard let uid = userID else { return }
        try await client.from("profile_interests").delete()
            .eq("profile_id", value: uid).execute()
        guard !slugs.isEmpty else { return }
        let rows = slugs.map { ProfileInterestRow(profile_id: uid, interest: $0) }
        try await client.from("profile_interests").insert(rows).execute()
    }

    static func replaceOwnPrompts(_ prompts: [(promptId: String, answer: String)]) async throws {
        guard let uid = userID else { return }
        try await client.from("profile_prompts").delete()
            .eq("profile_id", value: uid).execute()
        guard !prompts.isEmpty else { return }
        let rows = prompts.enumerated().map { i, p in
            ProfilePromptRow(profile_id: uid, prompt_id: p.promptId, answer: p.answer, position: i)
        }
        try await client.from("profile_prompts").insert(rows).execute()
    }

    // MARK: Photos

    /// Upload one photo slot and register it; replaces any previous file at the slot.
    static func uploadPhoto(_ data: Data, position: Int) async throws -> String {
        guard let uid = userID else { throw URLError(.userAuthenticationRequired) }
        let path = "\(uid.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from("photos").upload(
            path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        try await client.from("profile_photos").delete()
            .eq("profile_id", value: uid).eq("position", value: position).execute()
        try await client.from("profile_photos")
            .insert(ProfilePhotoRow(profile_id: uid, position: position, storage_path: path))
            .execute()
        return path
    }

    static func deletePhoto(position: Int) async throws {
        guard let uid = userID else { return }
        let rows: [ProfilePhotoRow] = try await client.from("profile_photos").select()
            .eq("profile_id", value: uid).eq("position", value: position).execute().value
        if let path = rows.first?.storage_path {
            try? await client.storage.from("photos").remove(paths: [path])
        }
        try await client.from("profile_photos").delete()
            .eq("profile_id", value: uid).eq("position", value: position).execute()
    }

    static func fetchPhotoRows(of profileID: UUID) async throws -> [ProfilePhotoRow] {
        try await client.from("profile_photos").select()
            .eq("profile_id", value: profileID).order("position").execute().value
    }

    static func downloadPhoto(path: String) async throws -> Data {
        try await client.storage.from("photos").download(path: path)
    }

    // MARK: Other profiles (for cards / detail)

    static func fetchInterestSlugs(of profileID: UUID) async throws -> [String] {
        let rows: [ProfileInterestRow] = try await client.from("profile_interests").select()
            .eq("profile_id", value: profileID).execute().value
        return rows.map(\.interest)
    }

    static func fetchPromptRows(of profileID: UUID) async throws -> [ProfilePromptRow] {
        try await client.from("profile_prompts").select()
            .eq("profile_id", value: profileID).order("position").execute().value
    }

    static func fetchProfile(_ profileID: UUID) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client.from("profiles").select()
            .eq("id", value: profileID).execute().value
        return rows.first
    }

    // MARK: Discovery / likes

    struct FeedParams: Encodable {
        let p_topics: [String]?
        let p_limit: Int
    }

    static func discoveryFeed(topics: [String]?, limit: Int = 20) async throws -> [FeedRow] {
        try await client.rpc("get_discovery_feed",
                             params: FeedParams(p_topics: topics, p_limit: limit))
            .execute().value
    }

    struct ActParams: Encodable {
        let p_target: UUID
        let p_action: String
    }

    static func actOnProfile(_ target: UUID, action: String) async throws -> ActResult {
        try await client.rpc("act_on_profile",
                             params: ActParams(p_target: target, p_action: action))
            .execute().value
    }

    static func likesRemaining() async throws -> Int {
        try await client.rpc("likes_remaining").execute().value
    }

    static func likers() async throws -> [LikerRow] {
        try await client.rpc("get_likers").execute().value
    }

    // MARK: Matches & messages

    static func fetchMatches() async throws -> [MatchRow] {
        try await client.from("matches").select()
            .order("created_at", ascending: false).execute().value
    }

    static func fetchMessages(matchID: UUID) async throws -> [MessageRow] {
        try await client.from("messages").select()
            .eq("match_id", value: matchID).order("created_at").execute().value
    }

    struct NewMessage: Encodable {
        let match_id: UUID
        let sender_id: UUID
        let body: String
    }

    static func sendMessage(matchID: UUID, body: String) async throws -> MessageRow {
        guard let uid = userID else { throw URLError(.userAuthenticationRequired) }
        let rows: [MessageRow] = try await client.from("messages")
            .insert(NewMessage(match_id: matchID, sender_id: uid, body: body))
            .select().execute().value
        guard let row = rows.first else { throw URLError(.badServerResponse) }
        return row
    }
}
