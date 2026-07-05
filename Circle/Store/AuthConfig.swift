//
//  AuthConfig.swift
//  Circle
//
//  Client-side auth configuration. Fill these in from your provider dashboards.
//

import Foundation

enum AuthConfig {

    /// The **iOS** OAuth client ID from Google Cloud Console
    /// (APIs & Services → Credentials → OAuth client ID → iOS).
    /// Looks like: 1234567890-abcdefg.apps.googleusercontent.com
    ///
    /// You must ALSO put the *reversed* form of this id
    /// (com.googleusercontent.apps.1234567890-abcdefg) into the URL scheme in
    /// `Info.plist` — see the comment there.
    static let googleClientID = "1076938664897-f9a3rgdt00clkpqmq217vg8v4hgl1fou.apps.googleusercontent.com"

    /// True once a real client id has been pasted in.
    static var googleConfigured: Bool {
        !googleClientID.hasPrefix("YOUR_")
    }
}
