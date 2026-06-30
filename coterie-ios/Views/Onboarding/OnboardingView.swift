//
//  OnboardingView.swift
//  coterie-ios
//
//  The introduction-builder: an eleven-step flow that shapes how a new member
//  appears to others. Progress, validation and persistence live in AppState.
//

import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var app: AppState

    private var step: OnboardingStep { app.steps[app.onboardingStep] }
    private var total: Int { app.steps.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                content
                    .id(app.onboardingStep)
                    .transition(.opacity)
                    .padding(.horizontal, 26)
                    .padding(.bottom, 24)
            }
            footer
        }
        .background(CT.paper.ignoresSafeArea())
    }

    // MARK: Header (progress)

    private var header: some View {
        HStack(spacing: 14) {
            if app.onboardingStep > 0 {
                Button { app.backOnboarding() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CT.ink)
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(CT.fill)
                    Capsule().fill(CT.ink)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 2)
            Text("\(pad(app.onboardingStep + 1)) / \(pad(total))")
                .font(.grotesk(10, weight: .regular))
                .tracking(1.8)
                .foregroundStyle(CT.muted)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .frame(height: 22)
    }

    private var progressFraction: CGFloat {
        CGFloat(app.onboardingStep + 1) / CGFloat(total)
    }

    private func pad(_ n: Int) -> String { String(format: "%02d", n) }

    // MARK: Footer (primary action)

    private var footer: some View {
        VStack {
            PillButton(title: buttonLabel, style: .filled, enabled: app.canAdvance(from: step)) {
                app.advanceOnboarding()
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(CT.hairlineSoft).frame(height: 1)
        }
    }

    private var buttonLabel: String {
        switch step {
        case .welcome: return "Begin"
        case .review:  return "Enter Circle"
        default:       return "Continue"
        }
    }

    // MARK: Step content

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:   WelcomeStep()
        case .name:      NameStep()
        case .birthday:  BirthdayStep()
        case .photos:    PhotosStep()
        case .about:     AboutStep()
        case .city:      CityStep()
        case .work:      WorkStep()
        case .prompt:    PromptStep()
        case .interests: InterestsStep()
        case .review:    ReviewStep()
        }
    }
}

// MARK: - Shared step header

private struct StepHeading: View {
    var title: String
    var subtitle: String?
    var topPad: CGFloat = 18
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.serif(34)).lineSpacing(2)
            if let subtitle {
                Text(subtitle).font(.grotesk(14.5)).foregroundStyle(CT.bodyLight).lineSpacing(3)
            }
        }
        .padding(.top, topPad)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Invitation Accepted").eyebrow(CT.muted, tracking: 3.0)
                .padding(.bottom, 22)
            Text("Welcome to Circle.").font(.serif(46)).lineSpacing(2)
            Text("You’ve been introduced by someone we trust. The next few moments shape how you’ll appear to others — there are no wrong answers, only honest ones.")
                .font(.grotesk(15.5)).foregroundStyle(CT.body).lineSpacing(5)
                .padding(.top, 20).frame(maxWidth: 300, alignment: .leading)
            Text("It takes about two minutes.")
                .serifItalic(20).foregroundStyle(CT.muted).padding(.top, 30)
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NameStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "What should we call you?",
                        subtitle: "Your first name is how members will know you.")
            UnderlineField(placeholder: "First name",
                           text: app.bind(\.name), fontSize: 30)
                .padding(.top, 34)
        }
    }
}

private struct BirthdayStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "When’s your birthday?",
                        subtitle: "We show your age, never your date of birth.")
            HStack(alignment: .bottom, spacing: 16) {
                dobField("Day", "DD", app.digitBind(\.dobD, 2))
                dobField("Month", "MM", app.digitBind(\.dobM, 2))
                dobField("Year", "YYYY", app.digitBind(\.dobY, 4), wide: true)
            }
            .padding(.top, 36)
            Text(app.profile.age.map { "You’ll appear as \($0)" } ?? " ")
                .serifItalic(17).foregroundStyle(CT.muted)
                .padding(.top, 24).frame(height: 22)
        }
    }

    /// Each column shares the row width; the year column is given a little more.
    private func dobField(_ label: String, _ placeholder: String,
                          _ binding: Binding<String>, wide: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).eyebrow(CT.muted, tracking: 2.0)
            UnderlineField(placeholder: placeholder, text: binding,
                           fontSize: 28, alignment: .leading, keyboard: .numberPad)
        }
        .frame(maxWidth: .infinity)
        .frame(minWidth: wide ? 96 : 64)
    }
}

private struct PhotosStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "Show your world.",
                        subtitle: "Add at least two. The best photographs say something true — not just a good angle.")
            PhotoGrid()
                .padding(.top, 28)
            Text(photoHint)
                .font(.grotesk(12)).foregroundStyle(CT.muted)
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.top, 16)
        }
    }
    private var photoHint: String {
        let c = app.profile.filledPhotoCount
        if c >= 2 { return "\(c) added" }
        return c == 0 ? "Tap a frame to add a photo" : "Add at least one more"
    }
}

/// The reusable 6-slot photo grid (used in onboarding and edit profile).
struct PhotoGrid: View {
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(0..<6, id: \.self) { i in
                PhotoSlot(index: i)
            }
        }
    }
}

/// A single photo slot backed by the system photo picker. Tap to choose or
/// replace; the corner button removes.
private struct PhotoSlot: View {
    @EnvironmentObject var app: AppState
    let index: Int
    @State private var pickerItem: PhotosPickerItem?

    private var data: Data? { app.profile.photos[index] }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $pickerItem, matching: .images,
                         photoLibrary: .shared()) {
                slotContent
            }
            .buttonStyle(PressableStyle())

            if data != nil {
                Button {
                    app.removePhoto(index)
                    pickerItem = nil
                } label: {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.5))
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(7)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                let loaded = try? await newItem.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let loaded { app.setPhoto(index, loaded) }
                    // Reset so reopening the picker starts clean and re-picking the
                    // same image still fires this handler.
                    pickerItem = nil
                }
            }
        }
    }

    @ViewBuilder private var slotContent: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(CT.photoEmpty)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ProfilePhoto(data: data) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(CT.border)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(CT.muted)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AboutStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            StepHeading(title: "Tell us who you are.", subtitle: nil)
            chipGroup("I am", options: CTData.pronouns,
                      isOn: { app.profile.pronouns == $0 },
                      tap: { app.profile.pronouns = $0 })
            chipGroup("Interested in meeting", options: CTData.seeking,
                      isOn: { app.profile.seeking == $0 },
                      tap: { app.profile.seeking = $0 })
        }
    }

    private func chipGroup(_ label: String, options: [String],
                           isOn: @escaping (String) -> Bool,
                           tap: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label).eyebrow(CT.muted, tracking: 2.2)
            FlowLayout(spacing: 10) {
                ForEach(options, id: \.self) { o in
                    ChoiceChip(label: o, selected: isOn(o)) { tap(o) }
                }
            }
        }
    }
}

private struct CityStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "Where are you based?",
                        subtitle: "We introduce members city by city.")
            UnderlineField(placeholder: "Your city", text: app.bind(\.city), fontSize: 28)
                .padding(.top, 30)
            FlowLayout(spacing: 9) {
                ForEach(CTData.cities, id: \.self) { c in
                    ChoiceChip(label: c, selected: app.profile.city == c,
                               fontSize: 12.5, hPad: 16, vPad: 9) { app.profile.city = c }
                }
            }
            .padding(.top, 24)
        }
    }
}

private struct WorkStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "What do you do?",
                        subtitle: "However you’d describe it — a title, a craft, a calling.")
            UnderlineField(placeholder: "e.g. Architect, Writer, Founder",
                           text: app.bind(\.work), fontSize: 28)
                .padding(.top, 32)
        }
    }
}

private struct PromptStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "Answer a few prompts.",
                        subtitle: "Choose up to three. Members fall for the way people answer these.")
            PromptComposer()
                .padding(.top, 26)
        }
    }
}

/// Lets the member pick up to three prompts from the full list and answer each,
/// all on one page. Reused in onboarding and edit-profile.
struct PromptComposer: View {
    @EnvironmentObject var app: AppState
    /// Which empty slot is currently choosing a prompt (true = the picker is open).
    @State private var picking = false

    var body: some View {
        VStack(spacing: 16) {
            ForEach(app.profile.prompts) { resp in
                answeredCard(resp)
            }

            if app.profile.prompts.count < AppState.maxPrompts {
                if picking {
                    picker
                } else {
                    Button { withAnimation(.easeOut(duration: 0.2)) { picking = true } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text(app.profile.prompts.isEmpty ? "Choose a prompt" : "Add another prompt")
                                .font(.grotesk(13, weight: .medium)).tracking(0.4)
                        }
                        .foregroundStyle(CT.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CT.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(CT.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(PressableStyle(scale: 0.99))
                }
            }
        }
    }

    private func answeredCard(_ resp: PromptResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(CTData.promptText(resp.promptId) ?? "")
                    .eyebrow(CT.accent, tracking: 2.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { withAnimation { app.removePrompt(resp.id) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(CT.muted)
                        .frame(width: 24, height: 24)
                        .background(CT.fill).clipShape(Circle())
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
            AnswerEditor(text: app.promptAnswerBind(resp.id), height: 88)
        }
        .padding(16)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CT.border, lineWidth: 1)
        )
    }

    private var picker: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Pick a prompt").eyebrow(CT.muted, tracking: 2.2)
                Spacer()
                Button { withAnimation { picking = false } } label: {
                    Text("Cancel").font(.grotesk(12, weight: .medium)).foregroundStyle(CT.muted)
                }
            }
            .padding(.bottom, 4)
            ForEach(app.availablePrompts, id: \.id) { p in
                ChoiceRow(label: p.q, selected: false, fontSize: 18) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        app.addPrompt(p.id)
                        picking = false
                    }
                }
            }
        }
        .padding(16)
        .background(CT.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CT.hairline, lineWidth: 1)
        )
    }
}

/// A bordered multi-line answer field with placeholder.
struct AnswerEditor: View {
    @Binding var text: String
    var height: CGFloat = 96
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Your answer…")
                    .font(.grotesk(15)).foregroundStyle(CT.faint)
                    .padding(.horizontal, 18).padding(.vertical, 16)
            }
            TextEditor(text: $text)
                .font(.grotesk(15))
                .foregroundStyle(CT.ink90)
                .tint(CT.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(height: height)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CT.border, lineWidth: 1)
        )
    }
}

private struct InterestsStep: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(alignment: .leading) {
            StepHeading(title: "What moves you?", subtitle: "Choose at least three.")
            FlowLayout(spacing: 9) {
                ForEach(CTData.interests, id: \.self) { t in
                    ChoiceChip(label: t, selected: app.profile.interests.contains(t),
                               fontSize: 13, hPad: 16, vPad: 10) { app.toggleInterest(t) }
                }
            }
            .padding(.top, 26)
            Text(interestHint).font(.grotesk(12)).foregroundStyle(CT.muted).padding(.top, 18)
        }
    }
    private var interestHint: String {
        let c = app.profile.interests.count
        return c >= 3 ? "\(c) selected" : "Choose at least \(3 - c) more"
    }
}

private struct ReviewStep: View {
    @EnvironmentObject var app: AppState
    private var p: UserProfile { app.profile }
    var body: some View {
        VStack(spacing: 0) {
            ProfilePhoto(data: p.firstPhoto) {
                Color(hex: "E6E4E0")
            }
            .frame(width: 132, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 25, x: 0, y: 20)

            Text(p.name + (p.age.map { ", \($0)" } ?? ""))
                .font(.serif(40)).multilineTextAlignment(.center).padding(.top, 26)
            Text((p.work) + (p.city.isEmpty ? "" : " · \(p.city)"))
                .eyebrow(CT.muted, tracking: 2.0).padding(.top, 10)
            Text(p.interests.prefix(3).joined(separator: "   ·   "))
                .serifItalic(18).foregroundStyle(CT.body).padding(.top, 18)

            Rectangle().fill(CT.border).frame(width: 34, height: 1)
                .padding(.vertical, 26)

            Text("Your introduction is ready. From here, we’ll show you one person a day — and show you to a few who’ll be glad to know you.")
                .font(.grotesk(15)).foregroundStyle(CT.body).multilineTextAlignment(.center)
                .lineSpacing(5).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }
}

// MARK: - AppState binding helpers

extension AppState {
    /// A two-way binding into a string field of the profile.
    func bind(_ keyPath: WritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(get: { self.profile[keyPath: keyPath] },
                set: { self.profile[keyPath: keyPath] = $0 })
    }

    /// A binding that keeps only digits, capped at `limit` characters.
    func digitBind(_ keyPath: WritableKeyPath<UserProfile, String>, _ limit: Int) -> Binding<String> {
        Binding(get: { self.profile[keyPath: keyPath] },
                set: { self.profile[keyPath: keyPath] = String($0.filter(\.isNumber).prefix(limit)) })
    }
}
