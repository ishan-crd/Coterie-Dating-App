//
//  LikeComposer.swift
//  Circle
//
//  Shown when the user likes someone from the Explore deck: attach an optional
//  greeting that becomes the first message the moment you match.
//

import SwiftUI

struct LikeComposer: View {
    @EnvironmentObject var app: AppState
    let member: Member

    @State private var note = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    private var photo: Data? { app.memberPhotos[member.id]?.first }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tap-to-dismiss scrim.
            Color.black.opacity(appeared ? 0.32 : 0)
                .ignoresSafeArea()
                .onTapGesture { app.cancelLike() }

            card
                .offset(y: appeared ? 0 : 420)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Capsule().fill(CT.border).frame(width: 38, height: 4).padding(.top, 10)

            HStack(spacing: 14) {
                ProfilePhoto(data: photo) {
                    PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: app.mood)
                }
                .frame(width: 52, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Say hi to \(member.name)").font(.serif(24)).foregroundStyle(CT.ink)
                    Text("Add a note — they’ll see it when you match.")
                        .font(.grotesk(12.5)).foregroundStyle(CT.muted)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)

            TextField("Write something warm… (optional)", text: $note, axis: .vertical)
                .font(.serif(18)).foregroundStyle(CT.ink).tint(CT.accent)
                .lineLimit(1...4)
                .focused($focused)
                .padding(14)
                .background(CT.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CT.border, lineWidth: 1))
                .padding(.top, 18)

            PillButton(title: note.trimmingCharacters(in: .whitespaces).isEmpty ? "Send Like" : "Send Like & Note",
                       style: .filled) {
                app.confirmLike(note: note)
            }
            .padding(.top, 16)

            Button { app.cancelLike() } label: {
                Text("Cancel").font(.grotesk(14, weight: .medium)).foregroundStyle(CT.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .background(CT.paper)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(CT.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: -6)
        .padding(.horizontal, 8)
    }
}
