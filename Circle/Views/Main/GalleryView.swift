//
//  GalleryView.swift
//  Circle
//
//  A small, curated selection of members presented as full-bleed portrait cards.
//

import SwiftUI

struct GalleryView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("The Gallery").eyebrow(CT.muted, tracking: 2.6).padding(.top, 18).padding(.bottom, 4)
                Text("Curated for you").font(.serif(33)).lineSpacing(2)
                Text("A small, considered selection. We’d rather show you six than six hundred.")
                    .font(.grotesk(14)).foregroundStyle(CT.bodyLight).lineSpacing(3)
                    .frame(maxWidth: 280, alignment: .leading)
                    .padding(.top, 4).padding(.bottom, 24)

                if app.feed.isEmpty {
                    VStack(spacing: 20) {
                        PulseRings(color: CT.accent, size: 64)
                        Text(app.feedLoading ? "Gathering people…" : "No one new right now.")
                            .font(.grotesk(14)).foregroundStyle(CT.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(app.feed) { member in
                        Button { app.openProfile(member.id) } label: {
                            GalleryCard(member: member, mood: app.mood,
                                        photo: app.memberPhotos[member.id]?.first)
                        }
                        .buttonStyle(PressableStyle(scale: 0.985))
                        .padding(.bottom, 26)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .safeAreaPadding(.top, 8)
    }
}

private struct GalleryCard: View {
    var member: Member
    var mood: PortraitMood
    var photo: Data? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ProfilePhoto(data: photo) {
                ZStack {
                    PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: mood)
                    Grain(opacity: 0.13)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.08), .black.opacity(0.62)],
                           startPoint: .init(x: 0.5, y: 0.42), endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(member.name).font(.serif(38)).foregroundStyle(.white)
                    Text("\(member.age)").font(.serif(22)).foregroundStyle(.white.opacity(0.78))
                }
                Text("\(member.role) · \(member.city)")
                    .font(.grotesk(10.5, weight: .regular)).tracking(2.0).textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.8)).padding(.top, 8)
                Text(member.bio).serifItalic(17).foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(3).padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .frame(height: 434)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 25, x: 0, y: 20)
    }
}
