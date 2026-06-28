//
//  Theme.swift
//  coterie-ios
//
//  Central design system — colours, type, gradients and shared modifiers.
//  Mirrors the "Coterie" editorial design: Cormorant Garamond (serif display)
//  paired with a grotesk body, on a warm paper background.
//

import SwiftUI
import UIKit

// MARK: - Colour palette

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: UInt64
        switch s.count {
        case 8: (r, g, b, a) = (v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        default: (r, g, b, a) = (v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

enum CT {
    // Surfaces
    static let paper = Color(hex: "FBFAF8")        // primary surface
    static let ink = Color(hex: "0B0B0B")          // primary text / buttons

    // Text tones
    static let ink90 = Color(hex: "16140F")
    static let ink80 = Color(hex: "1A1814")
    static let ink70 = Color(hex: "2A2823")
    static let body = Color(hex: "56534E")
    static let bodyLight = Color(hex: "76736E")
    static let muted = Color(hex: "9A9792")
    static let faint = Color(hex: "B6B3AE")
    static let fainter = Color(hex: "C2BFBA")
    static let tabIdle = Color(hex: "BCB9B4")

    static let hairline = Color.black.opacity(0.08)
    static let hairlineSoft = Color.black.opacity(0.06)

    // Warm paper backdrop gradient (root behind the app)
    static func rootBackground(_ tone: BackdropTone) -> LinearGradient {
        let stops: [Color]
        switch tone {
        case .warm:    stops = [Color(hex: "f1eee9"), Color(hex: "e5e1db"), Color(hex: "d6d2cb")]
        case .neutral: stops = [Color(hex: "f0efed"), Color(hex: "e6e5e2"), Color(hex: "d8d7d4")]
        case .cool:    stops = [Color(hex: "edeef0"), Color(hex: "e1e3e6"), Color(hex: "d2d5d9")]
        }
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Typography

extension Font {
    /// Cormorant Garamond stand-in — the system serif (New York) is an elegant match.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Hanken Grotesk stand-in — the default system grotesque.
    static func grotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension View {
    /// An italic serif line, used throughout for soft editorial asides.
    func serifItalic(_ size: CGFloat) -> some View {
        self.font(.serif(size)).italic()
    }

    /// Uppercase eyebrow label with wide tracking.
    func eyebrow(_ color: Color = CT.muted, tracking: CGFloat = 2.6) -> some View {
        self.font(.grotesk(10.5, weight: .medium))
            .tracking(tracking)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

// MARK: - Atmosphere settings

enum BackdropTone: String, CaseIterable, Codable {
    case warm = "Warm", neutral = "Neutral", cool = "Cool"
}

enum PortraitMood: String, CaseIterable, Codable {
    case studio = "Studio", highKey = "High-key", noir = "Noir"

    var palette: (hi: Color, mid: Color, lo: Color) {
        switch self {
        case .studio:  return (Color(hex: "e3e1dd"), Color(hex: "8d8b86"), Color(hex: "15140f"))
        case .highKey: return (Color(hex: "f2f0ec"), Color(hex: "c0bdb7"), Color(hex: "332f2a"))
        case .noir:    return (Color(hex: "cdcbc6"), Color(hex: "5e5c57"), Color(hex: "050504"))
        }
    }
}

// MARK: - Portrait gradient

/// Recreates the design's CSS "portrait" — a sculpted light-to-dark gradient that
/// stands in for a photograph. Two radial sheens (a bright highlight and a deep
/// shadow on the opposite corner) layered over a vertical base.
struct PortraitGradient: View {
    /// Light source position in 0...100 space, matching the source design.
    var lx: Double
    var ly: Double
    var mood: PortraitMood = .studio

    var body: some View {
        let p = mood.palette
        GeometryReader { geo in
            let s = max(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(colors: [p.hi, p.mid, p.lo],
                               startPoint: .top, endPoint: .bottom)

                RadialGradient(colors: [Color.white.opacity(0.95), .clear],
                               center: UnitPoint(x: lx / 100, y: ly / 100),
                               startRadius: 0, endRadius: s * 0.62)

                RadialGradient(colors: [Color(hex: "040404").opacity(0.97), .clear],
                               center: UnitPoint(x: (100 - lx) / 100, y: (100 - ly) / 100),
                               startRadius: 0, endRadius: s * 0.72)
            }
        }
    }
}

// MARK: - Grain overlay

/// A whisper of film grain laid over surfaces, as in the source design.
struct Grain: View {
    var opacity: Double = 0.05
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B9
            func rnd() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000
            }
            let step = 3.0
            var y = 0.0
            while y < size.height {
                var x = 0.0
                while x < size.width {
                    let a = rnd()
                    if a > 0.5 {
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        ctx.fill(Path(rect), with: .color(.black.opacity((a - 0.5) * 0.5)))
                    }
                    x += step
                }
                y += step
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - Reusable building blocks

/// The pill button used for primary / secondary actions throughout.
struct PillButton: View {
    enum Style { case filled, outline, ghost }
    var title: String
    var style: Style = .filled
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(.grotesk(12, weight: .medium))
                .tracking(2.2)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(foreground)
                .background(background)
                .clipShape(Capsule())
                .overlay(border)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.3), value: enabled)
    }

    private var foreground: Color {
        switch style {
        case .filled:  return enabled ? CT.paper : Color.black.opacity(0.32)
        case .outline, .ghost: return CT.ink
        }
    }
    private var background: Color {
        switch style {
        case .filled:  return enabled ? CT.ink : Color.black.opacity(0.07)
        case .outline: return CT.paper
        case .ghost:   return .clear
        }
    }
    @ViewBuilder private var border: some View {
        if style == .outline {
            Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1)
        }
    }
}

/// Subtle scale-down on press, echoing the design's `transform:scale(.97)`.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A selectable chip (interests, pronouns, cities…).
struct ChoiceChip: View {
    var label: String
    var selected: Bool
    var fontSize: CGFloat = 13.5
    var hPad: CGFloat = 20
    var vPad: CGFloat = 11
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.grotesk(fontSize))
                .foregroundStyle(selected ? CT.paper : CT.ink80)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(selected ? CT.ink : CT.paper)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? CT.ink : Color.black.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}

/// A full-width selectable row with a serif label (prompts, intentions…).
struct ChoiceRow: View {
    var label: String
    var selected: Bool
    var fontSize: CGFloat = 19
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.serif(fontSize))
                .foregroundStyle(selected ? CT.paper : CT.ink80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(selected ? CT.ink : CT.paper)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? CT.ink : Color.black.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(PressableStyle(scale: 0.99))
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}

/// An underlined, borderless serif text field — the signature input of the app.
struct UnderlineField: View {
    var placeholder: String
    @Binding var text: String
    var fontSize: CGFloat = 28
    var alignment: TextAlignment = .leading
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .font(.serif(fontSize))
                .foregroundStyle(CT.ink)
                .tint(CT.ink)
                .multilineTextAlignment(alignment)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(height: 1)
        }
    }
}
