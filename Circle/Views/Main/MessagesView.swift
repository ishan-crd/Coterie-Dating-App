//
//  MessagesView.swift
//  Circle
//
//  The list of ongoing conversations, ordered by recency.
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Messages").eyebrow(CT.muted, tracking: 2.6).padding(.top, 18).padding(.bottom, 4)
                Text("Conversations").font(.serif(33)).lineSpacing(2).padding(.bottom, 22)

                if app.conversationOrder.isEmpty {
                    VStack(spacing: 20) {
                        PulseRings(color: CT.accent, size: 64)
                        Text("Match with someone to start talking.")
                            .font(.grotesk(14)).foregroundStyle(CT.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(app.conversationOrder, id: \.self) { id in
                        if let convo = app.conversations[id], let member = app.member(id) {
                            Button { app.openChat(with: id) } label: {
                                ConversationRow(member: member, convo: convo, mood: app.mood,
                                                photo: app.memberPhotos[id]?.first)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .safeAreaPadding(.top, 8)
    }
}

private struct ConversationRow: View {
    var member: Member
    var convo: Conversation
    var mood: PortraitMood
    var photo: Data? = nil

    var body: some View {
        HStack(spacing: 16) {
            ProfilePhoto(data: photo) {
                ZStack {
                    PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: mood)
                    Grain(opacity: 0.14)
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(member.name).font(.serif(22))
                    Spacer()
                    Text(convo.time).font(.grotesk(11)).foregroundStyle(CT.faint)
                }
                Text("\(member.role) · \(member.city)")
                    .font(.grotesk(11)).foregroundStyle(CT.muted).padding(.vertical, 3)
                HStack(spacing: 8) {
                    Text(convo.preview).font(.grotesk(13.5)).foregroundStyle(CT.body)
                        .lineLimit(1).truncationMode(.tail)
                    if convo.unread {
                        Circle().fill(CT.ink).frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1) }
        .contentShape(Rectangle())
    }
}
