//
//  RootView.swift
//  Circle
//
//  Top-level router. Switches between loading, auth, onboarding and the main
//  app based on the session stage held in AppState.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()

            switch app.stage {
            case .loading:
                VStack(spacing: 24) {
                    LogoMark(height: 34)
                    PulseRings(color: CT.accent, size: 56)
                }
                .transition(.opacity)
            case .auth:
                AuthView()
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
