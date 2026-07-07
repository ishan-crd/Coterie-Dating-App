//
//  MatchMoment.swift
//  Circle
//
//  The "It's a match" celebration — shown when a like is mutual. Two portraits
//  lean toward each other over a warm wash; the user can open the conversation
//  or keep exploring.
//

import SwiftUI

struct MatchMoment: View {
    @EnvironmentObject var app: AppState
    let member: Member

    @State private var appeared = false

    private var ownPhoto: Data? { app.profile.firstPhoto }
    private var theirPhoto: Data? { app.memberPhotos[member.id]?.first }

    var body: some View {
        ZStack {
            // Warm dim over the app.
            CT.paper.opacity(0.18).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("A new friend")
                    .eyebrow(CT.accent, tracking: 3.0)
                    .opacity(appeared ? 1 : 0)

                Text("You’re both in.")
                    .font(.serif(46))
                    .foregroundStyle(CT.ink)
                    .padding(.top, 10)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)

                Text("You and \(member.name) liked each other. Say hello and see where it goes.")
                    .font(.grotesk(15))
                    .foregroundStyle(CT.body)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 14)
                    .opacity(appeared ? 1 : 0)

                portraits
                    .padding(.top, 40)

                Spacer()

                VStack(spacing: 12) {
                    PillButton(title: "Send a message", style: .filled) { app.messageMatch() }
                    Button { app.dismissMatch() } label: {
                        Text("Keep exploring")
                            .font(.grotesk(14, weight: .medium))
                            .foregroundStyle(CT.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { appeared = true }
        }
    }

    private var portraits: some View {
        HStack(spacing: -26) {
            portrait(data: ownPhoto, seedLx: 50, seedLy: 16)
                .rotationEffect(.degrees(appeared ? -6 : 0))
                .zIndex(1)
            portrait(data: theirPhoto, seedLx: member.portrait.lx, seedLy: member.portrait.ly)
                .rotationEffect(.degrees(appeared ? 6 : 0))
        }
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
    }

    private func portrait(data: Data?, seedLx: Double, seedLy: Double) -> some View {
        ProfilePhoto(data: data) {
            ZStack {
                PortraitGradient(lx: seedLx, ly: seedLy, mood: app.mood)
                Grain(opacity: 0.13)
            }
        }
        .frame(width: 150, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.paper, lineWidth: 4))
        .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 14)
    }
}
