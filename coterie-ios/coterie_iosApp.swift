//
//  coterie_iosApp.swift
//  coterie-ios
//
//  Created by Ishan Gupta on 28/06/26.
//

import SwiftUI
import GoogleSignIn

@main
struct coterie_iosApp: App {
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
