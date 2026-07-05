//
//  TodayView.swift
//  Circle
//
//  Explore: one person at a time, shown as a full scrolling profile — their
//  photos and prompts interleaved. Topic filters pin to the top; the pass / like
//  controls float statically over the scroll. Five likes a day.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState

    private var candidate: Member? { app.exploreCandidates.first }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let candidate {
                ZStack(alignment: .bottom) {
                    ProfileScroll(member: candidate, shared: app.sharedInterests(candidate))
                        .id(candidate.id)
                        .transition(.opacity)
                    floatingActions(for: candidate)
                }
                .animation(.easeOut(duration: 0.3), value: candidate.id)
            } else {
                Spacer()
                emptyState
                Spacer()
            }
        }
        .background(CT.paper.ignoresSafeArea())
    }

    // MARK: Top bar — name + horizontal topic filters

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                LogoMark(height: 20)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(CT.accent)
                    Text(app.likesRemaining == 1 ? "1 like left" : "\(app.likesRemaining) likes left")
                        .font(.grotesk(10.5, weight: .medium)).tracking(1.4)
                        .textCase(.uppercase).foregroundStyle(CT.muted)
                }
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ChoiceChip(label: "Everyone", selected: app.exploreTopics.isEmpty,
                               fontSize: 13, hPad: 16, vPad: 9) { app.clearTopics() }
                    ForEach(app.myTopics, id: \.self) { topic in
                        ChoiceChip(label: topic, selected: app.exploreTopics.contains(topic),
                                   fontSize: 13, hPad: 16, vPad: 9) { app.toggleTopic(topic) }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(
            CT.paper
                .overlay(alignment: .bottom) { Rectangle().fill(CT.hairlineSoft).frame(height: 1) }
        )
    }

    // MARK: Static pass / like controls

    private func floatingActions(for member: Member) -> some View {
        HStack {
            Button { app.passMember(member.id) } label: {
                actionCircle(system: "xmark", filled: false)
            }
            .buttonStyle(PressableStyle(scale: 0.9))

            Spacer()

            Button { app.likeMember(member.id) } label: {
                actionCircle(system: "heart.fill", filled: true)
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            .disabled(app.likesRemaining == 0)
            .opacity(app.likesRemaining == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 92)   // sit above the frosted tab bar
    }

    private func actionCircle(system: String, filled: Bool) -> some View {
        Image(systemName: system)
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(filled ? CT.accentInk : CT.ink70)
            .frame(width: 62, height: 62)
            .background(
                Circle().fill(filled ? AnyShapeStyle(CT.accent) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(Circle().stroke(filled ? Color.clear : CT.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            PulseRings(color: CT.accent, size: 84).padding(.bottom, 30)
            Text(app.feedLoading ? "Finding your people…"
                 : app.exploreTopics.isEmpty ? "You’re all caught up."
                                             : "No one new in these topics.")
                .font(.serif(30)).multilineTextAlignment(.center)
            Text(app.feedLoading ? " "
                 : app.exploreTopics.isEmpty
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
        .padding(.horizontal, 22)
    }
}

// MARK: - Scrolling profile (photos + prompts interleaved)

private struct ProfileScroll: View {
    @EnvironmentObject var app: AppState
    var member: Member
    var shared: [String]

    /// A few portrait framings derived from the member's light source — the
    /// fallback when they haven't uploaded photos.
    private var photoSeeds: [PortraitSeed] {
        let s = member.portrait
        func clamp(_ v: Double) -> Double { min(92, max(8, v)) }
        return [
            s,
            PortraitSeed(lx: clamp(100 - s.lx), ly: clamp(s.ly + 22)),
            PortraitSeed(lx: clamp(s.lx + 16), ly: clamp(100 - s.ly)),
        ]
    }

    /// Real uploaded photos, if any.
    private var photos: [Data] { app.memberPhotos[member.id] ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                nameHeader

                photo(0)

                if !shared.isEmpty { sharedCard }

                if member.prompts.indices.contains(0) {
                    promptCard(member.prompts[0])
                }

                if photos.count > 1 || photos.isEmpty { photo(1) }

                aboutCard

                if member.prompts.indices.contains(1) {
                    promptCard(member.prompts[1])
                }

                if photos.count > 2 || photos.isEmpty { photo(2) }

                if member.prompts.indices.contains(2) {
                    promptCard(member.prompts[2])
                }

                interestsCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 110)   // clear the floating controls
        }
    }

    // MARK: Header

    private var nameHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(member.name).font(.serif(40))
                Text("\(member.age)").font(.serif(28)).foregroundStyle(CT.body)
                Spacer()
            }
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("Active today")
                    .font(.grotesk(11, weight: .medium)).tracking(1.0).foregroundStyle(CT.muted)
                Text("·").foregroundStyle(CT.faint)
                Text("\(member.role) · \(member.city)")
                    .font(.grotesk(11, weight: .regular)).tracking(0.6).foregroundStyle(CT.muted)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: Photo panel

    private func photo(_ index: Int) -> some View {
        let seed = photoSeeds[min(index, photoSeeds.count - 1)]
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(CT.photoEmpty)
            .frame(height: 460)
            .overlay {
                ProfilePhoto(data: index < photos.count ? photos[index] : nil) {
                    ZStack {
                        PortraitGradient(lx: seed.lx, ly: seed.ly, mood: app.mood)
                        Grain(opacity: 0.13)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }

    // MARK: Cards

    private func promptCard(_ prompt: PromptAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.q).eyebrow(CT.muted, tracking: 2.4)
            Text(prompt.a).font(.serif(27)).foregroundStyle(CT.ink90).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.border, lineWidth: 1))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About").eyebrow(CT.muted, tracking: 2.4)
            Text(member.bio).serifItalic(22).foregroundStyle(CT.ink80).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.border, lineWidth: 1))
    }

    private var sharedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What you share").eyebrow(CT.accent, tracking: 2.4)
            FlowLayout(spacing: 8) {
                ForEach(shared, id: \.self) { tag in
                    Text(tag)
                        .font(.grotesk(12, weight: .semibold))
                        .foregroundStyle(CT.accentInk)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(CT.accent).clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(CT.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var interestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Into").eyebrow(CT.muted, tracking: 2.4)
            FlowLayout(spacing: 8) {
                ForEach(member.interests, id: \.self) { TagPill(text: $0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.border, lineWidth: 1))
    }
}
