//
//  GoogleAuth.swift
//  Circle
//
//  Native Google Sign-In: presents Google's own sheet and returns an ID token
//  we exchange with Supabase. Configure the client id in AuthConfig.
//

import UIKit
import GoogleSignIn

enum GoogleAuth {

    struct Tokens {
        let idToken: String
        let accessToken: String
    }

    enum GoogleAuthError: LocalizedError {
        case notConfigured
        case noPresenter
        case noIDToken

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Google sign-in isn't configured yet."
            case .noPresenter:   return "Couldn't present Google sign-in."
            case .noIDToken:     return "Google didn't return an identity token."
            }
        }
    }

    /// Handle the redirect back from Google (call from `.onOpenURL`).
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    @MainActor
    static func signIn() async throws -> Tokens {
        guard AuthConfig.googleConfigured else { throw GoogleAuthError.notConfigured }
        guard let presenter = topViewController() else { throw GoogleAuthError.noPresenter }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: AuthConfig.googleClientID)

        // GoogleSignIn (via AppAuth) generates its own nonce inside the id_token
        // but never exposes it, so we can't send a matching one to Supabase.
        // Enable "Skip nonce checks" on the Supabase Google provider for this flow.
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.noIDToken
        }
        return Tokens(idToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
