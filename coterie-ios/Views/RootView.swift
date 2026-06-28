//
//  RootView.swift
//  coterie-ios
//
//  Top-level router. Switches between the invitation flow, onboarding and the
//  main app based on the session stage held in AppState.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()

            switch app.stage {
            case .invite:
                InviteView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .opacity))
            case .app:
                MainTabView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: app.stage)
        .preferredColorScheme(app.appearance.colorScheme)
        .animation(.easeInOut(duration: 0.35), value: app.appearance)
    }
}
