//
//  TodayView.swift
//  coterie-ios
//
//  Explore: find people who share your interests. Choose the topics you care
//  about, then like or pass — five likes a day.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState

    private var candidate: Member? { app.exploreCandidates.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text("Find your people.")
                    .font(.serif(33)).lineSpacing(3)
                    .padding(.top, 6).padding(.bottom, 16)

                likesPill
                topicFilter

                if let candidate {
                    PersonCard(member: candidate, shared: app.sharedInterests(candidate))
                        .id(candidate.id)
                        .transition(.asymmetric(insertion: .opacity,
                                                removal: .scale(scale: 0.92).combined(with: .opacity)))
                        .padding(.top, 18)
                    actionRow(for: candidate)
                        .padding(.top, 18)
                } else {
                    emptyState.padding(.top, 30)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 120)
            .animation(.easeOut(duration: 0.3), value: candidate?.id)
        }
        .safeAreaPadding(.top, 8)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dateString).eyebrow(CT.muted, tracking: 2.6)
            Spacer()
            LogoMark(height: 19)
        }
        .padding(.top, 18).padding(.bottom, 4)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: Likes allowance

    private var likesPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CT.accent)
            Text(app.likesRemaining == 1 ? "1 like left today"
                                         : "\(app.likesRemaining) likes left today")
                .font(.grotesk(12, weight: .medium)).tracking(0.4)
                .foregroundStyle(CT.ink80)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(CT.accentSoft)
        .clipShape(Capsule())
    }

    // MARK: Topic filter

    private var topicFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Show me people into").eyebrow(CT.muted, tracking: 2.2)
                .padding(.top, 22)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ChoiceChip(label: "Everyone", selected: app.exploreTopics.isEmpty,
                               fontSize: 13, hPad: 16, vPad: 9) { app.clearTopics() }
                    ForEach(app.myTopics, id: \.self) { topic in
                        ChoiceChip(label: topic, selected: app.exploreTopics.contains(topic),
                                   fontSize: 13, hPad: 16, vPad: 9) { app.toggleTopic(topic) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Action row

    private func actionRow(for member: Member) -> some View {
        HStack(spacing: 14) {
            Button { app.passMember(member.id) } label: {
                circleAction(system: "xmark", filled: false)
            }
            .buttonStyle(PressableStyle(scale: 0.9))

            Button { app.likeMember(member.id) } label: {
                circleAction(system: "heart.fill", filled: true)
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .disabled(app.likesRemaining == 0)
            .opacity(app.likesRemaining == 0 ? 0.4 : 1)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .center) {
            if app.likesRemaining == 0 {
                Text("Out of likes — back tomorrow")
                    .font(.grotesk(11, weight: .medium)).tracking(0.5)
                    .foregroundStyle(CT.muted)
                    .offset(y: 44)
            }
        }
    }

    private func circleAction(system: String, filled: Bool) -> some View {
        Image(systemName: system)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(filled ? CT.accentInk : CT.ink70)
            .frame(width: 64, height: 64)
            .background(filled ? CT.accent : CT.surface)
            .clipShape(Circle())
            .overlay(Circle().stroke(filled ? Color.clear : CT.border, lineWidth: 1))
            .shadow(color: .black.opacity(filled ? 0.25 : 0.08), radius: 14, x: 0, y: 8)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            PulseRings(color: CT.accent, size: 84).padding(.bottom, 30)
            Text(app.exploreTopics.isEmpty ? "You’re all caught up."
                                           : "No one new in these topics.")
                .font(.serif(30)).multilineTextAlignment(.center)
            Text(app.exploreTopics.isEmpty
                 ? "You’ve seen everyone for now. New people join all the time — check back soon."
                 : "Try removing a topic, or come back later as more people join.")
                .font(.grotesk(14.5)).foregroundStyle(CT.bodyLight)
                .multilineTextAlignment(.center).lineSpacing(5)
                .padding(.top, 14).frame(maxWidth: 270)

            if !app.passedIDs.isEmpty {
                PillButton(title: "Start Over", style: .outline) { app.resetDeck() }
                    .padding(.top, 30)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

// MARK: - Person card

private struct PersonCard: View {
    @EnvironmentObject var app: AppState
    var member: Member
    var shared: [String]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PortraitGradient(lx: member.portrait.lx, ly: member.portrait.ly, mood: app.mood)
            Grain(opacity: 0.13)
            LinearGradient(colors: [.clear, .black.opacity(0.1), .black.opacity(0.7)],
                           startPoint: .init(x: 0.5, y: 0.38), endPoint: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(member.name) · \(member.age)")
                        .font(.serif(38)).foregroundStyle(.white)
                    Text("\(member.role) · \(member.city)")
                        .font(.grotesk(11, weight: .regular)).tracking(2.2)
                        .textCase(.uppercase).foregroundStyle(.white.opacity(0.82))
                }
                interestTags
            }
            .padding(24)
        }
        .frame(height: 452)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.42), radius: 32, x: 0, y: 24)
    }

    private var interestTags: some View {
        FlowLayout(spacing: 8) {
            ForEach(member.interests, id: \.self) { tag in
                let isShared = shared.contains(tag)
                Text(tag)
                    .font(.grotesk(12, weight: isShared ? .semibold : .regular))
                    .foregroundStyle(isShared ? CT.accentInk : .white)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(isShared ? AnyShapeStyle(CT.accent)
                                         : AnyShapeStyle(.ultraThinMaterial))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(isShared ? 0 : 0.3), lineWidth: 1))
            }
        }
    }
}
