//
//  ProfileDetailView.swift
//  coterie-ios
//
//  A full member profile, opened from the gallery or invitations, with the
//  option to pass or introduce yourself.
//

import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject var app: AppState
    var memberID: String

    private var member: Member? { CTData.member(memberID) }

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()
            if let member {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero(member)
                        details(member)
                    }
                }
                .ignoresSafeArea(edges: .top)

                VStack { Spacer(); footer(member) }
            }
        }
    }

    private func hero(_ member: Member) -> some View {
        ZStack(alignment: .bottomLeading) {
            PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: app.mood)
            Grain(opacity: 0.13)
            LinearGradient(colors: [.black.opacity(0.18), .clear, .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(member.name).font(.serif(48)).foregroundStyle(.white)
                    Text("\(member.age)").font(.serif(26)).foregroundStyle(.white.opacity(0.8))
                }
                Text("\(member.role) · \(member.city)")
                    .font(.grotesk(11, weight: .regular)).tracking(2.0).textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(26)
        }
        .frame(height: 486)
        .overlay(alignment: .topLeading) {
            Button { app.closeSheet() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .padding(.leading, 22).padding(.top, 60)
        }
    }

    private func details(_ member: Member) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(member.bio).font(.serif(23)).foregroundStyle(CT.ink80).lineSpacing(5)

            block("Why you were introduced") {
                Text(member.why).serifItalic(21).foregroundStyle(CT.ink90).lineSpacing(4)
            }

            ForEach(member.prompts) { pr in
                block(pr.q) {
                    Text("“\(pr.a)”").font(.serif(25)).foregroundStyle(CT.ink90).lineSpacing(3)
                }
            }

            block("Interests") {
                FlowLayout(spacing: 9) {
                    ForEach(member.interests, id: \.self) { TagPill(text: $0) }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 140)
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).eyebrow(CT.muted, tracking: 2.6)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1).padding(.top, -22) }
        .padding(.top, 22)
    }

    private func footer(_ member: Member) -> some View {
        HStack(spacing: 12) {
            Button { app.closeSheet() } label: {
                sheetAction("Pass", filled: false)
            }
            .buttonStyle(PressableStyle(scale: 0.96))
            Button { app.openChat(with: member.id) } label: {
                sheetAction("Introduce Yourself", filled: true)
            }
            .buttonStyle(PressableStyle(scale: 0.96))
            .frame(maxWidth: .infinity).layoutPriority(1)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 30)
        .background(
            CT.paper.opacity(0.85).background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func sheetAction(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.grotesk(12, weight: .regular)).tracking(2.0).textCase(.uppercase)
            .foregroundStyle(filled ? CT.accentInk : CT.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(filled ? CT.accent : CT.paper)
            .clipShape(Capsule())
            .overlay(filled ? nil : Capsule().stroke(CT.borderStrong, lineWidth: 1))
    }
}
