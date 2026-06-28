//
//  Persistence.swift
//  coterie-ios
//
//  Lightweight UserDefaults-backed persistence for the signed-in profile and
//  preferences. This is what lets a returning member skip the invitation flow.
//

import Foundation

struct StoredSettings: Codable {
    var notifications: Bool
    var paused: Bool
    var appearance: AppearanceMode
}

enum Persistence {
    private static let profileKey = "coterie.profile"
    private static let settingsKey = "coterie.settings"
    private static let defaults = UserDefaults.standard

    // MARK: Profile

    static func saveProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
    }

    static func loadProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    // MARK: Settings

    static func saveSettings(_ settings: StoredSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    static func loadSettings() -> StoredSettings? {
        guard let data = defaults.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(StoredSettings.self, from: data)
        else { return nil }
        return s
    }

    // MARK: Reset

    static func clear() {
        defaults.removeObject(forKey: profileKey)
        // Preferences intentionally preserved across sessions.
    }
}
