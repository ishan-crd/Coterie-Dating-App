//
//  CircleApp.swift
//  Circle
//
//  Created by Ishan Gupta on 28/06/26.
//

import SwiftUI
import GoogleSignIn
import UserNotifications

@main
struct CircleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .onOpenURL { url in
                    _ = GoogleAuth.handle(url)
                }
        }
    }
}

/// Receives the APNs device token and forwards it to `AppState`, and presents
/// notifications while the app is foregrounded. Push only functions once the
/// Push Notifications capability + APNs key are configured (see HANDOFF §8);
/// until then registration fails quietly.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var appState: AppState?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in AppDelegate.appState?.registerPushToken(hex) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected until the Push Notifications capability is enabled.
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
