//
//  EditProfileView.swift
//  coterie-ios
//
//  Edit the signed-in member's profile. Reuses the onboarding building blocks.
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    label("Photos")
                    PhotoGrid().padding(.top, 4)

                    label("Name").padding(.top, 30)
                    UnderlineField(placeholder: "First name", text: app.bind(\.name), fontSize: 26)

                    label("Birthday").padding(.top, 28)
                    HStack(spacing: 16) {
                        UnderlineField(placeholder: "DD", text: app.digitBind(\.dobD, 2),
                                       fontSize: 24, alignment: .leading, keyboard: .numberPad)
                        UnderlineField(placeholder: "MM", text: app.digitBind(\.dobM, 2),
                                       fontSize: 24, alignment: .leading, keyboard: .numberPad)
                        UnderlineField(placeholder: "YYYY", text: app.digitBind(\.dobY, 4),
                                       fontSize: 24, alignment: .leading, keyboard: .numberPad)
                    }

                    label("I am").padding(.top, 28)
                    chips(CTData.pronouns, isOn: { app.profile.pronouns == $0 }) { app.profile.pronouns = $0 }

                    label("Interested in meeting").padding(.top, 24)
                    chips(CTData.seeking, isOn: { app.profile.seeking == $0 }) { app.profile.seeking = $0 }

                    label("City").padding(.top, 28)
                    UnderlineField(placeholder: "Your city", text: app.bind(\.city), fontSize: 24)

                    label("Work").padding(.top, 28)
                    UnderlineField(placeholder: "e.g. Architect, Writer, Founder", text: app.bind(\.work), fontSize: 24)

                    label("Your prompt").padding(.top, 28)
                    VStack(spacing: 9) {
                        ForEach(CTData.prompts, id: \.id) { p in
                            ChoiceRow(label: p.q, selected: app.profile.promptId == p.id, fontSize: 18) {
                                app.profile.promptId = p.id
                            }
                        }
                    }
                    if !app.profile.promptId.isEmpty {
                        AnswerEditor(text: app.bind(\.answer), height: 92).padding(.top, 8)
                    }

                    label("Interests").padding(.top, 28)
                    FlowLayout(spacing: 9) {
                        ForEach(CTData.interests, id: \.self) { t in
                            ChoiceChip(label: t, selected: app.profile.interests.contains(t),
                                       fontSize: 13, hPad: 16, vPad: 10) { app.toggleInterest(t) }
                        }
                    }
                }
                .padding(.horizontal, 26).padding(.top, 24).padding(.bottom, 60)
            }
            footer
        }
        .background(CT.paper.ignoresSafeArea())
    }

    private var navBar: some View {
        HStack {
            Button { app.closeSheet() } label: {
                Text("Cancel").font(.grotesk(14)).foregroundStyle(CT.muted)
            }
            Spacer()
            Text("Edit Profile").font(.grotesk(11)).tracking(2.2).textCase(.uppercase).foregroundStyle(CT.ink)
            Spacer()
            Button { save() } label: {
                Text("Done").font(.grotesk(14, weight: .semibold)).foregroundStyle(CT.ink)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(
            CT.paper.opacity(0.85).background(.ultraThinMaterial)
                .overlay(alignment: .bottom) { Rectangle().fill(CT.hairline).frame(height: 1) }
        )
    }

    private var footer: some View {
        PillButton(title: "Done", style: .filled) { save() }
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 16)
            .background(CT.paper.opacity(0.9)
                .overlay(alignment: .top) { Rectangle().fill(CT.hairlineSoft).frame(height: 1) })
    }

    private func save() {
        app.saveProfileEdits()
        app.closeSheet()
    }

    private func label(_ t: String) -> some View {
        Text(t).eyebrow(CT.muted, tracking: 2.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
    }

    private func chips(_ options: [String], isOn: @escaping (String) -> Bool,
                       tap: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(options, id: \.self) { o in
                ChoiceChip(label: o, selected: isOn(o), hPad: 18) { tap(o) }
            }
        }
    }
}
