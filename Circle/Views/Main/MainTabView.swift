//
//  MainTabView.swift
//  Circle
//
//  The signed-in shell: scrollable tab content beneath a frosted glass tab bar,
//  with profile / chat / edit presented as full-screen sheets.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            CT.paper.ignoresSafeArea()

            // Active tab content
            Group {
                switch app.tab {
                case .today:    TodayView()
                case .gallery:  GalleryView()
                case .invites:  InvitesView()
                case .messages: MessagesView()
                case .profile:  ProfileView()
                }
            }
            .transition(.opacity)

            GlassTabBar()

            if let matched = app.matchedMember {
                MatchMoment(member: matched)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .fullScreenCover(item: $app.activeSheet) { sheet in
            switch sheet {
            case .profile(let id): ProfileDetailView(memberID: id)
            case .chat(let id):    ChatView(memberID: id)
            case .edit:            EditProfileView()
            }
        }
    }
}

// MARK: - Glass tab bar

private struct GlassTabBar: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack {
            tab(.today, "sparkle", "Today")
            tab(.gallery, "rectangle.on.rectangle", "Gallery")
            tab(.invites, "envelope", "Invites", badge: true)
            tab(.messages, "bubble.left", "Messages")
            tab(.profile, "person", "You")
        }
        .padding(.horizontal, 17)
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .background(
            CT.paper.opacity(0.72)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ t: MainTab, _ icon: String, _ label: String, badge: Bool = false) -> some View {
        let active = app.tab == t
        return Button {
            withAnimation(.easeInOut(duration: 0.3)) { app.tab = t }
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 21, weight: .light))
                    if badge {
                        Circle().fill(CT.accent)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(CT.paper, lineWidth: 1.5))
                            .offset(x: 5, y: -3)
                    }
                }
                Text(label)
                    .font(.grotesk(9, weight: .regular))
                    .tracking(1.4)
                    .textCase(.uppercase)
            }
            .foregroundStyle(active ? CT.accent : CT.tabIdle)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
