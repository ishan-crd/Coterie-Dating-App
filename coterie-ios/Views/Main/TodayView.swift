//
//  TodayView.swift
//  coterie-ios
//
//  A single introduction a day. The portrait arrives sealed and blurred; the
//  member reveals it, then chooses to pass or introduce themselves.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var app: AppState
    private var match: Member { app.dailyMatch }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text("One introduction, chosen for you today.")
                    .font(.serif(33)).lineSpacing(3)
                    .frame(maxWidth: 300, alignment: .leading)
                    .padding(.top, 6).padding(.bottom, 22)

                if app.dailyOutcome != .none {
                    doneCard
                } else {
                    introductionCard
                    if app.revealed { revealedDetail.transition(.opacity) }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 120)
        }
        .safeAreaPadding(.top, 8)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dateString).eyebrow(CT.muted, tracking: 2.6)
            Spacer()
            Text("Coterie").font(.serif(21)).tracking(0.8)
        }
        .padding(.top, 18).padding(.bottom, 4)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: Sealed / revealed card

    private var introductionCard: some View {
        ZStack {
            // Portrait
            PortraitGradient(lx: match.portrait.lx, ly: match.portrait.ly, mood: app.mood)
                .blur(radius: app.revealed ? 0 : 30)
                .grayscale(app.revealed ? 0 : 0.45)
                .brightness(app.revealed ? 0 : 0.05)
                .scaleEffect(app.revealed ? 1 : 1.12)
                .animation(.easeOut(duration: 1.1), value: app.revealed)

            Grain(opacity: 0.13)

            // Bottom gradient (only once revealed)
            LinearGradient(colors: [.clear, .black.opacity(0.08), .black.opacity(0.66)],
                           startPoint: .init(x: 0.5, y: 0.4), endPoint: .bottom)
                .opacity(app.revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.9), value: app.revealed)

            // Sealed dim
            Color.black.opacity(0.34)
                .opacity(app.revealed ? 0 : 1)
                .animation(.easeOut(duration: 0.8), value: app.revealed)

            // Name block
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                HStack { nameBlock; Spacer() }
            }
            .padding(26)
            .opacity(app.revealed ? 1 : 0)
            .offset(y: app.revealed ? 0 : 14)
            .animation(.easeOut(duration: 0.8).delay(0.15), value: app.revealed)

            // Sealed centre
            if !app.revealed { sealedCentre.transition(.opacity) }
        }
        .frame(height: 452)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.42), radius: 32, x: 0, y: 24)
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(match.name).font(.serif(44)).foregroundStyle(.white)
            Text("\(match.age) · \(match.city) · \(match.role)")
                .font(.grotesk(11, weight: .regular)).tracking(2.4)
                .textCase(.uppercase).foregroundStyle(.white.opacity(0.82))
        }
    }

    private var sealedCentre: some View {
        VStack(spacing: 0) {
            Text("Today’s Introduction")
                .font(.grotesk(10.5, weight: .regular)).tracking(3.0)
                .textCase(.uppercase).foregroundStyle(.white.opacity(0.78))
                .padding(.bottom, 30)
            PulseRings().padding(.bottom, 30)
            Button { app.reveal() } label: {
                Text("Reveal")
                    .font(.grotesk(12, weight: .regular)).tracking(2.2).textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(PressableStyle(scale: 0.95))
        }
    }

    // MARK: Revealed detail

    private var revealedDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Why you were introduced").eyebrow(CT.muted, tracking: 2.6)
                Text(match.why).serifItalic(23).foregroundStyle(CT.ink80).lineSpacing(4)
            }
            .padding(.top, 26)

            VStack(alignment: .leading, spacing: 8) {
                Text(match.prompts[0].q).eyebrow(CT.muted, tracking: 2.6)
                Text("“\(match.prompts[0].a)”").font(.serif(25)).foregroundStyle(CT.ink90).lineSpacing(3)
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Rectangle().fill(CT.hairline).frame(height: 1) }
            .padding(.top, 6)

            HStack(spacing: 12) {
                Button { app.passDaily() } label: {
                    actionLabel("Pass", filled: false)
                }
                .buttonStyle(PressableStyle(scale: 0.96))
                Button { app.introduceDaily() } label: {
                    actionLabel("Introduce Yourself", filled: true)
                }
                .buttonStyle(PressableStyle(scale: 0.96))
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            }
            .padding(.top, 24)
        }
    }

    private func actionLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.grotesk(12, weight: .regular)).tracking(2.0).textCase(.uppercase)
            .foregroundStyle(filled ? CT.paper : CT.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(filled ? CT.ink : CT.paper)
            .clipShape(Capsule())
            .overlay(filled ? nil : Capsule().stroke(CT.borderStrong, lineWidth: 1))
    }

    // MARK: Done

    private var doneCard: some View {
        VStack(spacing: 0) {
            Circle().fill(CT.ink).frame(width: 8, height: 8).padding(.bottom, 26)
            Text(app.dailyOutcome == .passed ? "Until tomorrow." : "Introduction sent.")
                .font(.serif(36)).multilineTextAlignment(.center)
            Text(app.dailyOutcome == .passed
                 ? "You let this one pass. Coterie offers a single introduction a day — yours returns in the morning."
                 : "Your note is on its way. We curate one introduction a day; the next arrives tomorrow.")
                .font(.grotesk(14.5)).foregroundStyle(CT.bodyLight)
                .multilineTextAlignment(.center).lineSpacing(5)
                .padding(.top, 16).frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity).frame(height: 430)
        .padding(40)
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(CT.border, lineWidth: 1))
    }
}

// MARK: - Pulsing rings (sealed state ornament)

private struct PulseRings: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ring(delay: 0)
            ring(delay: 1.2)
            Circle().fill(.white).frame(width: 7, height: 7)
        }
        .frame(width: 70, height: 70)
        .onAppear { animate = true }
    }

    private func ring(delay: Double) -> some View {
        Circle().stroke(.white.opacity(0.5), lineWidth: 1)
            .scaleEffect(animate ? 1.7 : 0.7)
            .opacity(animate ? 0 : 0.55)
            .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay),
                       value: animate)
    }
}
