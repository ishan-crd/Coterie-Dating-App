//
//  ProfileView.swift
//  Circle
//
//  The signed-in member's own profile, appearance and account settings.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    private var p: UserProfile { app.profile }
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                portraitCard
                PillButton(title: "Edit Profile", style: .outline) { app.activeSheet = .edit }
                    .padding(.top, 16)

                ForEach(p.prompts.filter { !$0.answer.isEmpty }) { resp in
                    promptSection(app.promptQuestion(resp.promptId) ?? "", resp.answer)
                }
                if !p.interests.isEmpty { interestsSection }

                appearanceSection
                preferencesSection
                accountSection

                PillButton(title: "Log Out", style: .outline) { app.logout() }
                    .padding(.top, 30)

                Button { showDeleteConfirm = true } label: {
                    Text("Delete Account")
                        .font(.grotesk(13, weight: .medium))
                        .foregroundStyle(CT.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Text("Circle · Find your people")
                    .font(.grotesk(11)).tracking(2.0).textCase(.uppercase)
                    .foregroundStyle(CT.fainter)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .safeAreaPadding(.top, 8)
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) { app.deleteAccount() }
        } message: {
            Text("This permanently clears your profile, photos, prompts and interests. You can sign back in anytime to start over. Are you sure?")
        }
    }

    // MARK: Header & portrait

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Your Profile").eyebrow(CT.muted, tracking: 2.6)
            Spacer()
            LogoMark(height: 19)
        }
        .padding(.top, 18).padding(.bottom, 12)
    }

    private var portraitCard: some View {
        ZStack(alignment: .bottomLeading) {
            ProfilePhoto(data: p.firstPhoto) {
                ZStack {
                    PortraitGradient(lx: 50, ly: 16, mood: app.mood)
                    Grain(opacity: 0.13)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.1), .black.opacity(0.64)],
                           startPoint: .init(x: 0.5, y: 0.44), endPoint: .bottom)
            VStack(alignment: .leading, spacing: 9) {
                Text((p.name.isEmpty ? "Your profile" : p.name) + (p.age.map { ", \($0)" } ?? ""))
                    .font(.serif(40)).foregroundStyle(.white)
                Text((p.work.isEmpty ? "Add your details" : p.work) + (p.city.isEmpty ? "" : " · \(p.city)"))
                    .font(.grotesk(10.5, weight: .regular)).tracking(2.0).textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 28, x: 0, y: 22)
    }

    // MARK: Content sections

    private func promptSection(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(q).eyebrow(CT.muted, tracking: 2.6)
            Text("“\(a)”").font(.serif(24)).foregroundStyle(CT.ink90).lineSpacing(3)
                .padding(.top, 8).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 30)
        .overlay(alignment: .bottom) { Rectangle().fill(CT.hairline).frame(height: 1) }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Interests").eyebrow(CT.muted, tracking: 2.6)
            FlowLayout(spacing: 9) {
                ForEach(p.interests, id: \.self) { t in TagPill(text: t) }
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Appearance").padding(.top, 34)
            segmentRow("Theme",
                       options: AppearanceMode.allCases.map(\.rawValue),
                       selected: app.appearance.rawValue) { raw in
                if let m = AppearanceMode(rawValue: raw) {
                    withAnimation(.easeInOut(duration: 0.35)) { app.appearance = m }
                }
            }
            .padding(.top, 16)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Preferences").padding(.top, 34)
            toggleRow("New introductions", "A daily notification at 8am",
                      isOn: Binding(get: { app.notifications }, set: { app.notifications = $0 }))
                .padding(.top, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(CT.hairlineSoft).frame(height: 1) }
            toggleRow("Pause introductions", "Quietly step away for a while",
                      isOn: Binding(get: { app.paused }, set: { app.paused = $0 }))
            linkRow("Who you’d like to meet", trailing: p.seeking.isEmpty ? "Everyone" : p.seeking) {
                app.activeSheet = .edit
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Account").padding(.top, 30)
            HStack {
                Text("Membership").font(.grotesk(15)).foregroundStyle(CT.ink80)
                Spacer()
                Text("Member since 2026").font(.grotesk(13)).foregroundStyle(CT.muted)
            }
            .padding(.vertical, 18).padding(.top, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(CT.hairlineSoft).frame(height: 1) }
            linkRow("Privacy & safety") {}
            linkRow("Help & support") {}
            linkRow("About Circle") {}
        }
    }

    // MARK: Row helpers

    private func sectionLabel(_ t: String) -> some View {
        Text(t).eyebrow(CT.muted, tracking: 2.6).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmentRow(_ title: String, options: [String], selected: String,
                            onPick: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title).font(.grotesk(14.5)).foregroundStyle(CT.ink80)
            Spacer()
            HStack(spacing: 3) {
                ForEach(options, id: \.self) { o in
                    let on = o == selected
                    Button { onPick(o) } label: {
                        Text(o).font(.grotesk(11.5)).foregroundStyle(on ? CT.paper : CT.body)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(on ? CT.ink : .clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableStyle(scale: 0.96))
                }
            }
            .padding(4)
            .background(CT.fill)
            .clipShape(Capsule())
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.grotesk(15)).foregroundStyle(CT.ink80)
                Text(subtitle).font(.grotesk(12.5)).foregroundStyle(CT.muted)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(CT.ink)
        }
        .padding(.vertical, 16)
    }

    private func linkRow(_ title: String, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.grotesk(15)).foregroundStyle(CT.ink80)
                Spacer()
                if let trailing {
                    Text(trailing).font(.grotesk(13)).foregroundStyle(CT.muted)
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CT.faint)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(CT.hairlineSoft).frame(height: 1) }
    }
}

/// An uppercase outlined tag used to display interests.
struct TagPill: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.grotesk(11)).tracking(1.1).textCase(.uppercase).foregroundStyle(CT.ink70)
            .padding(.horizontal, 15).padding(.vertical, 8)
            .overlay(Capsule().stroke(CT.border, lineWidth: 1))
    }
}
