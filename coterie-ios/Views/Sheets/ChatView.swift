//
//  ChatView.swift
//  coterie-ios
//
//  A one-to-one conversation, with a composer and a simulated reply.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var app: AppState
    var memberID: String
    @State private var draft = ""

    private var member: Member? { CTData.member(memberID) }
    private var convo: Conversation? { app.conversations[memberID] }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            messages
            composer
        }
        .background(CT.paper.ignoresSafeArea())
    }

    // MARK: Nav bar

    private var navBar: some View {
        HStack(spacing: 13) {
            Button { app.closeSheet() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(CT.ink)
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            if let member {
                ZStack {
                    PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: app.mood)
                    Grain(opacity: 0.14)
                }
                .frame(width: 40, height: 40).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name).font(.serif(21))
                    Text("\(member.role) · \(member.city)")
                        .font(.grotesk(10, weight: .regular)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(CT.muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(
            CT.paper.opacity(0.85).background(.ultraThinMaterial)
                .overlay(alignment: .bottom) { Rectangle().fill(CT.hairline).frame(height: 1) }
        )
    }

    // MARK: Messages

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    Text("Introduced by Coterie")
                        .font(.grotesk(10.5, weight: .regular)).tracking(2.0).textCase(.uppercase)
                        .foregroundStyle(CT.faint).padding(.bottom, 12)

                    ForEach(convo?.messages ?? []) { msg in
                        bubble(msg).id(msg.id)
                    }
                    if app.typing { typingBubble.id("typing") }
                }
                .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: convo?.messages.count ?? 0) { _, _ in
                if let last = convo?.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: app.typing) { _, t in
                if t { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.fromMe { Spacer(minLength: 50) }
            Text(msg.text)
                .font(.grotesk(15)).lineSpacing(2)
                .foregroundStyle(msg.fromMe ? .white : CT.ink90)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(msg.fromMe ? CT.ink : CT.bubbleThem)
                .clipShape(BubbleShape(fromMe: msg.fromMe))
            if !msg.fromMe { Spacer(minLength: 50) }
        }
    }

    private var typingBubble: some View {
        HStack {
            TypingDots()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(CT.bubbleThem)
                .clipShape(BubbleShape(fromMe: false))
            Spacer(minLength: 50)
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Write something considered…", text: $draft)
                .font(.grotesk(15)).tint(CT.ink)
                .padding(.horizontal, 18).padding(.vertical, 13)
                .background(CT.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(CT.border, lineWidth: 1))
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(CT.ink).clipShape(Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.9))
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
        .background(
            CT.paper.opacity(0.85).background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1) }
        )
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        app.send(text, to: memberID)
    }
}

// MARK: - Bubble shape (asymmetric corner)

private struct BubbleShape: Shape {
    var fromMe: Bool
    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 22, small: CGFloat = 7
        let tl = big, tr = big
        let br = fromMe ? small : big
        let bl = fromMe ? big : small
        return Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
            topLeading: tl, bottomLeading: bl, bottomTrailing: br, topTrailing: tr))
    }
}

// MARK: - Typing indicator

private struct TypingDots: View {
    @State private var phase = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(CT.muted).frame(width: 6, height: 6)
                    .offset(y: phase ? -3 : 0)
                    .animation(.easeInOut(duration: 0.65).repeatForever().delay(Double(i) * 0.2),
                               value: phase)
            }
        }
        .onAppear { phase = true }
    }
}
