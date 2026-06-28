//
//  Models.swift
//  coterie-ios
//
//  Domain models for members, the signed-in user's profile, and conversations.
//

import Foundation

// MARK: - App stage

enum AppStage {
    case invite
    case onboarding
    case app
}

// MARK: - Member (someone you can be introduced to)

struct PromptAnswer: Identifiable, Hashable {
    var id = UUID()
    var q: String
    var a: String
}

/// A portrait is described by the position of its light source so it can be
/// rendered with the user's current mood palette.
struct PortraitSeed: Hashable {
    var lx: Double
    var ly: Double
}

struct Member: Identifiable, Hashable {
    let id: String
    var name: String
    var age: Int
    var city: String
    var role: String
    var portrait: PortraitSeed
    var bio: String
    var why: String
    var prompts: [PromptAnswer]
    var interests: [String]
}

// MARK: - Conversations

struct ChatMessage: Identifiable, Hashable, Codable {
    var id = UUID()
    var fromMe: Bool
    var text: String
}

struct Conversation: Identifiable, Hashable {
    var id: String          // member id
    var preview: String
    var time: String
    var unread: Bool
    var messages: [ChatMessage]
}

struct Invitation: Identifiable, Hashable {
    var id: String          // member id
    var note: String
    var time: String
}

// MARK: - The signed-in user's profile (persisted)

struct UserProfile: Codable, Equatable {
    var name = ""
    var dobM = ""
    var dobD = ""
    var dobY = ""
    /// Six photo slots; a non-nil value stores the portrait seed for the gradient.
    var photos: [PortraitSeedCodable?] = Array(repeating: nil, count: 6)
    var pronouns = ""
    var seeking = ""
    var city = ""
    var work = ""
    var promptId = ""
    var answer = ""
    var interests: [String] = []
    var intention = ""

    /// Age derived from the full date of birth, relative to today.
    var age: Int? {
        guard dobY.count == 4, let y = Int(dobY) else { return nil }
        let m = Int(dobM) ?? 1
        let d = Int(dobD) ?? 1
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        let cal = Calendar.current
        guard let birth = cal.date(from: c) else { return nil }
        return cal.dateComponents([.year], from: birth, to: Date()).year
    }

    var filledPhotoCount: Int { photos.compactMap { $0 }.count }
    var firstPhoto: PortraitSeedCodable? { photos.compactMap { $0 }.first }

    var isComplete: Bool { !name.isEmpty && filledPhotoCount >= 2 }
}

#if DEBUG
extension UserProfile {
    /// A fully populated profile used only for previewing the signed-in app.
    static var sample: UserProfile {
        var p = UserProfile()
        p.name = "Aurelio"
        p.dobM = "04"; p.dobD = "12"; p.dobY = "1994"
        p.photos[0] = PortraitSeedCodable(lx: 40, ly: 18)
        p.photos[1] = PortraitSeedCodable(lx: 66, ly: 30)
        p.pronouns = "He / Him"
        p.seeking = "Everyone"
        p.city = "Lisbon"
        p.work = "Architect"
        p.promptId = "sunday"
        p.answer = "A flea market at dawn, a long lunch, and absolutely no plans after."
        p.interests = ["Architecture", "Film photography", "Natural wine", "Sailing"]
        p.intention = "Something genuine and unhurried"
        return p
    }
}
#endif

/// Codable mirror of PortraitSeed for persistence.
struct PortraitSeedCodable: Codable, Equatable, Hashable {
    var lx: Double
    var ly: Double
    var seed: PortraitSeed { PortraitSeed(lx: lx, ly: ly) }
}

// MARK: - Reference data

enum CTData {
    static let pronouns = ["She / Her", "He / Him", "They / Them"]
    static let seeking = ["Women", "Men", "Everyone"]
    static let cities = ["Paris", "London", "New York", "Copenhagen", "Lisbon", "Stockholm"]

    static let prompts: [(id: String, q: String)] = [
        ("sunday", "A perfect Sunday is…"),
        ("fall", "I’ll fall for someone who…"),
        ("win", "The way to win me over…"),
        ("alive", "I feel most alive when…"),
        ("view", "An opinion I’ll defend…"),
    ]

    static let interests = [
        "Film photography", "Architecture", "Natural wine", "Ceramics", "Vinyl",
        "Open water", "Literature", "Jazz", "Hiking", "Cooking", "Cinema",
        "Travel", "Tennis", "Design", "Sailing", "Pottery",
    ]

    static let intentions = [
        "A relationship, when it’s right",
        "Something genuine and unhurried",
        "To meet remarkable people",
        "Open to seeing where it leads",
    ]

    /// Fixed photo light-positions for the six profile slots.
    static let photoPositions: [PortraitSeed] = [
        .init(lx: 30, ly: 18), .init(lx: 70, ly: 22), .init(lx: 50, ly: 14),
        .init(lx: 66, ly: 78), .init(lx: 34, ly: 70), .init(lx: 58, ly: 30),
    ]

    /// The member directory shown in the gallery, invites and daily introduction.
    static let members: [Member] = [
        Member(id: "margot", name: "Margot", age: 27, city: "Paris", role: "Gallerist",
               portrait: .init(lx: 28, ly: 16),
               bio: "Curates contemporary work at a gallery tucked in the Marais.",
               why: "You were both drawn to slow mornings, film photography, and the city of Lisbon.",
               prompts: [.init(q: "A perfect Sunday", a: "A flea market at dawn, a long lunch, no phone."),
                         .init(q: "I’ll fall for", a: "Someone who notices the small, deliberate things.")],
               interests: ["Film photography", "Ceramics", "Natural wine", "Joan Didion"]),
        Member(id: "elias", name: "Elias", age: 32, city: "Copenhagen", role: "Composer",
               portrait: .init(lx: 74, ly: 20),
               bio: "Writes for film and the occasional empty concert hall.",
               why: "A shared love of late records and quiet architecture.",
               prompts: [.init(q: "On repeat", a: "Arvo Pärt, and the hum of the city at 2am."),
                         .init(q: "We’ll get along if", a: "You can sit in a comfortable silence.")],
               interests: ["Analog synths", "Sailing", "Brutalism", "Espresso"]),
        Member(id: "saoirse", name: "Saoirse", age: 29, city: "London", role: "Architect",
               portrait: .init(lx: 50, ly: 12),
               bio: "Designs quiet houses that let the light do the talking.",
               why: "Both of you listed Lisbon and long walks with no destination.",
               prompts: [.init(q: "The dream project", a: "A stone cabin on the Atlantic, off the grid."),
                         .init(q: "My weakness", a: "Good paper, bad coffee, worse puns.")],
               interests: ["Sketching", "Open water", "Tea", "Tadao Ando"]),
        Member(id: "cyrus", name: "Cyrus", age: 34, city: "New York", role: "Filmmaker",
               portrait: .init(lx: 70, ly: 80),
               bio: "Makes documentaries about people who build things by hand.",
               why: "A mutual fondness for old cameras and older jazz.",
               prompts: [.init(q: "Last great meal", a: "A stranger’s kitchen in Oaxaca."),
                         .init(q: "Find me", a: "In the last row of a repertory cinema.")],
               interests: ["16mm film", "Vinyl", "Boxing", "Murakami"]),
        Member(id: "ingrid", name: "Ingrid", age: 30, city: "Stockholm", role: "Perfumer",
               portrait: .init(lx: 32, ly: 72),
               bio: "Builds scents the way others write short stories.",
               why: "You both believe a meal is always better outdoors.",
               prompts: [.init(q: "My signature", a: "Cedar, salt, and rain on warm stone."),
                         .init(q: "Take me to", a: "A greenhouse, in the middle of winter.")],
               interests: ["Botany", "Cold swims", "Linen", "Tarkovsky"]),
        Member(id: "theo", name: "Theo", age: 31, city: "Lisbon", role: "Designer",
               portrait: .init(lx: 60, ly: 28),
               bio: "Makes furniture meant to outlive whoever buys it.",
               why: "Two people who would always rather make than buy.",
               prompts: [.init(q: "In my hands lately", a: "A chair I’ve rebuilt four times over."),
                         .init(q: "I admire", a: "Anyone with a craft and the patience for it.")],
               interests: ["Woodwork", "Surfing", "Pastel de nata", "Le Corbusier"]),
    ]

    static func member(_ id: String) -> Member? { members.first { $0.id == id } }

    static let invitations: [Invitation] = [
        .init(id: "saoirse", note: "I saw your photographs in the gallery. I’d like to be introduced.", time: "2h"),
        .init(id: "theo", note: "Anyone who’d rather make than buy has my attention.", time: "Yesterday"),
        .init(id: "cyrus", note: "We seem to keep almost crossing paths. Hello.", time: "2d"),
    ]

    static let replyPool = [
        "That made me smile.",
        "Tell me more — I’m intrigued.",
        "I had a feeling we’d get along.",
        "Then it’s settled. When are you free?",
    ]
}
