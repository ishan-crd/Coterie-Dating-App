//
//  WaitlistView.swift
//  coterie-ios
//
//  Request-an-invitation form for non-members, with a confirmation state.
//

import SwiftUI

struct WaitlistView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var instagram = ""
    @State private var city = ""
    @State private var submitted = false

    private var canSubmit: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2 &&
        instagram.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        ZStack {
            CT.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .medium))
                        Text("Back").font(.grotesk(13)).tracking(0.5)
                    }
                    .foregroundStyle(CT.ink)
                }
                .padding(.top, 8)

                if submitted {
                    confirmation
                } else {
                    form
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 24)
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("Membership")
                .eyebrow(CT.muted, tracking: 3.0)
                .padding(.bottom, 18)

            Text("Request an\ninvitation.")
                .font(.serif(42))
                .lineSpacing(2)

            Text("We admit a small number of members each month, by hand. Tell us only where to find you.")
                .font(.grotesk(14.5))
                .foregroundStyle(CT.bodyLight)
                .lineSpacing(4)
                .padding(.top, 16)
                .frame(maxWidth: 286, alignment: .leading)

            field("First name", placeholder: "Your name", text: $name)
                .padding(.top, 38)

            VStack(alignment: .leading, spacing: 10) {
                Text("Instagram").eyebrow(CT.muted, tracking: 2.2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("@").font(.serif(25)).foregroundStyle(CT.faint)
                    TextField("username", text: $instagram)
                        .font(.serif(25)).tint(CT.ink).foregroundStyle(CT.ink)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CT.border).frame(height: 1).offset(y: 12)
                }
            }
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text("City").eyebrow(CT.muted, tracking: 2.2)
                    Text("— optional").font(.grotesk(10.5)).foregroundStyle(CT.fainter)
                }
                UnderlineField(placeholder: "Where you’re based", text: $city, fontSize: 25)
            }
            .padding(.top, 26)

            PillButton(title: "Request Invitation", style: .filled, enabled: canSubmit) {
                withAnimation(.easeOut(duration: 0.4)) { submitted = true }
            }
            .padding(.top, 40)

            Spacer(minLength: 0)
        }
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).eyebrow(CT.muted, tracking: 2.2)
            UnderlineField(placeholder: placeholder, text: text, fontSize: 25)
        }
    }

    // MARK: Confirmation

    private var confirmation: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(CT.ink)
            Text("You’re on the list.")
                .font(.serif(40))
                .multilineTextAlignment(.center)
                .padding(.top, 26)
            Text("Membership is reviewed by hand. If it’s a fit, an invitation will quietly find its way to you.")
                .font(.grotesk(14.5))
                .foregroundStyle(CT.bodyLight)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.top, 14)
                .frame(maxWidth: 248)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
