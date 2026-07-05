//
//  CircleApp.swift
//  Circle
//
//  Created by Ishan Gupta on 28/06/26.
//

import SwiftUI
import GoogleSignIn

@main
struct CircleApp: App {
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
