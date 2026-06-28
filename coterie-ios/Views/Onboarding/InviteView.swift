//
//  InviteView.swift
//  coterie-ios
//
//  The doorway to Coterie: an invitation-code entry, with a quiet path to the
//  waitlist for those not yet members.
//

import SwiftUI

struct InviteView: View {
    @EnvironmentObject var app: AppState
    @FocusState private var focused: Bool
    @State private var showWaitlist = false

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()

            VStack {
                // Eyebrow
                HStack(spacing: 14) {
                    rule
                    Text("By Invitation Only")
                        .font(.grotesk(10.5, weight: .medium))
                        .tracking(3.6)
                        .textCase(.uppercase)
                        .foregroundStyle(CT.muted)
                    rule
                }
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 0) {
                    Text("Coterie")
                        .font(.serif(62))
                        .tracking(2.5)
                    Text("Introductions, made with intention.")
                        .serifItalic(18)
                        .foregroundStyle(CT.bodyLight)
                        .padding(.top, 14)

                    VStack(spacing: 0) {
                        Text("Enter your invitation")
                            .font(.grotesk(11))
                            .tracking(2.6)
                            .textCase(.uppercase)
                            .foregroundStyle(CT.muted)
                            .padding(.bottom, 20)

                        codeField

                        // Verifying / error state
                        ZStack {
                            if app.verifying {
                                statusText("Verifying your invitation…", color: CT.bodyLight)
                            } else if app.inviteError {
                                statusText("That invitation wasn’t recognised.", color: Color(hex: "9A6A60"))
                            }
                        }
                        .frame(height: 20)
                        .padding(.top, 14)
                        .animation(.easeInOut, value: app.verifying)
                        .animation(.easeInOut, value: app.inviteError)
                    }
                    .padding(.top, 54)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("Not yet a member?")
                        .font(.grotesk(13))
                        .foregroundStyle(CT.muted)
                    Button {
                        focused = false
                        showWaitlist = true
                    } label: {
                        Text("Request an invitation")
                            .font(.grotesk(13))
                            .foregroundStyle(CT.ink)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(CT.ink.opacity(0.35)).frame(height: 1).offset(y: 3)
                            }
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 36)
        }
        .fullScreenCover(isPresented: $showWaitlist) {
            WaitlistView()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true } }
    }

    private var rule: some View {
        Rectangle().fill(CT.ink.opacity(0.25)).frame(width: 30, height: 1)
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.grotesk(11))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .transition(.opacity)
    }

    /// Six evenly-spaced cells (a dash until filled) over a hidden input field.
    private var codeField: some View {
        let chars = Array(app.inviteCode)
        return ZStack {
            // Hidden field that actually captures keystrokes.
            TextField("", text: Binding(
                get: { app.inviteCode },
                set: { app.onInviteChanged($0) }
            ))
            .focused($focused)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .tint(.clear)
            .foregroundStyle(.clear)
            .accentColor(.clear)
            .frame(width: 240)
            .opacity(0.01)

            // Visible cells.
            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { i in
                    let isActive = focused && i == chars.count
                    Text(i < chars.count ? String(chars[i]) : "–")
                        .font(.serif(32))
                        .foregroundStyle(i < chars.count ? CT.ink
                                         : (isActive ? CT.bodyLight : CT.faint))
                        .frame(width: 24)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 240)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CT.border).frame(height: 1).offset(y: 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}
