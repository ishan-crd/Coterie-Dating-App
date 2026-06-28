//
//  InvitesView.swift
//  coterie-ios
//
//  Members who have personally requested an introduction to you.
//

import SwiftUI

struct InvitesView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Invitations").eyebrow(CT.muted, tracking: 2.6).padding(.top, 18).padding(.bottom, 4)
                Text("Asked for you").font(.serif(33)).lineSpacing(2)
                Text("A few members have requested an introduction. Accept only what feels right.")
                    .font(.grotesk(14)).foregroundStyle(CT.bodyLight).lineSpacing(3)
                    .frame(maxWidth: 282, alignment: .leading)
                    .padding(.top, 4).padding(.bottom, 26)

                ForEach(CTData.invitations) { invite in
                    if let member = CTData.member(invite.id) {
                        Button { app.openProfile(member.id) } label: {
                            InviteRow(member: member, invite: invite, mood: app.mood)
                        }
                        .buttonStyle(PressableStyle(scale: 0.99))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .safeAreaPadding(.top, 8)
    }
}

private struct InviteRow: View {
    var member: Member
    var invite: Invitation
    var mood: PortraitMood

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .bottom) {
                PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: mood)
                Grain(opacity: 0.14)
                LinearGradient(colors: [.clear, .black.opacity(0.3)],
                               startPoint: .init(x: 0.5, y: 0.55), endPoint: .bottom)
            }
            .frame(width: 92, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(member.name).font(.serif(25))
                        Text("\(member.age)").font(.serif(16)).foregroundStyle(CT.muted)
                    }
                    Spacer()
                    Text(invite.time).font(.grotesk(11)).foregroundStyle(CT.faint)
                }
                Text("\(member.role) · \(member.city)")
                    .font(.grotesk(10, weight: .regular)).tracking(1.8).textCase(.uppercase)
                    .foregroundStyle(CT.muted).padding(.top, 5).padding(.bottom, 10)
                Text("“\(invite.note)”").serifItalic(17).foregroundStyle(CT.ink70).lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 22)
        .overlay(alignment: .bottom) { Rectangle().fill(CT.hairline).frame(height: 1) }
        .padding(.bottom, 22)
    }
}
