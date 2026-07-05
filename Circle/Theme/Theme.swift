//
//  Theme.swift
//  Circle
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

extension Color {
    /// A colour that resolves differently in light and dark appearance.
    static func dyn(_ light: Color, _ dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Semantic colour tokens. Every value adapts to light / dark appearance, so
/// switching the app theme flips the whole chrome automatically. Portraits and
/// the text laid over them stay as-is — they read as photographs in both modes.
enum CT {
    // Surfaces
    static let paper   = Color.dyn(Color(hex: "FBFAF8"), Color(hex: "100F0D"))  // primary surface
    static let surface = Color.dyn(Color(hex: "FFFFFF"), Color(hex: "1C1B18"))  // lifted fields/cards
    static let ink     = Color.dyn(Color(hex: "0B0B0B"), Color(hex: "F4F1EC"))  // primary text / buttons

    // Warm accent — primary actions, selections & active nav
    static let accent    = Color.dyn(Color(hex: "E0674A"), Color(hex: "F07E5E"))
    static let accentInk = Color.dyn(Color(hex: "FFFFFF"), Color(hex: "1A0F0B"))  // text laid over accent
    static let accentSoft = Color.dyn(Color(hex: "E0674A").opacity(0.12), Color(hex: "F07E5E").opacity(0.16))

    // Text tones
    static let ink90     = Color.dyn(Color(hex: "16140F"), Color(hex: "ECE8E2"))
    static let ink80     = Color.dyn(Color(hex: "1A1814"), Color(hex: "E2DED7"))
    static let ink70     = Color.dyn(Color(hex: "2A2823"), Color(hex: "D2CEC6"))
    static let body      = Color.dyn(Color(hex: "56534E"), Color(hex: "ADA89F"))
    static let bodyLight = Color.dyn(Color(hex: "76736E"), Color(hex: "948F86"))
    static let muted     = Color.dyn(Color(hex: "9A9792"), Color(hex: "7B776F"))
    static let faint     = Color.dyn(Color(hex: "B6B3AE"), Color(hex: "615D57"))
    static let fainter   = Color.dyn(Color(hex: "C2BFBA"), Color(hex: "4D4A45"))
    static let tabIdle   = Color.dyn(Color(hex: "BCB9B4"), Color(hex: "5A5650"))

    // Lines, borders & fills
    static let hairline     = Color.dyn(.black.opacity(0.08), .white.opacity(0.12))
    static let hairlineSoft = Color.dyn(.black.opacity(0.06), .white.opacity(0.09))
    static let border       = Color.dyn(.black.opacity(0.16), .white.opacity(0.20))
    static let borderStrong = Color.dyn(.black.opacity(0.20), .white.opacity(0.26))
    static let fill         = Color.dyn(.black.opacity(0.06), .white.opacity(0.10))
    static let disabledFill = Color.dyn(.black.opacity(0.07), .white.opacity(0.10))
    static let disabledInk  = Color.dyn(.black.opacity(0.32), .white.opacity(0.30))

    // Component-specific surfaces
    static let bubbleThem = Color.dyn(Color(hex: "F0EEEA"), Color(hex: "262320"))
    static let photoEmpty = Color.dyn(Color(hex: "F1EFEB"), Color(hex: "211F1D"))
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

/// The user-selectable app theme.
enum AppearanceMode: String, CaseIterable, Codable {
    case system = "System", light = "Light", dark = "Dark"

    /// The scheme to force, or `nil` to follow the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
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

// MARK: - Brand

/// The Circle wordmark. Rendered as serif type so it adopts the theme colour
/// and always reads the current name.
struct LogoMark: View {
    var height: CGFloat
    var color: Color = CT.ink

    var body: some View {
        Text("Circle")
            .font(.serif(height * 1.05, weight: .medium))
            .tracking(height * 0.04)
            .foregroundStyle(color)
            .accessibilityLabel("Circle")
    }
}

// MARK: - Profile photo

/// Renders an uploaded profile photo (JPEG `Data`), or a placeholder when empty.
struct ProfilePhoto<Placeholder: View>: View {
    var data: Data?
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder()
        }
    }
}

// MARK: - Pulsing rings

/// Two expanding rings around a centre dot — a soft "listening / searching"
/// ornament. Colour-configurable so it reads on both light surfaces and photos.
struct PulseRings: View {
    var color: Color = .white
    var size: CGFloat = 70
    @State private var animate = false

    var body: some View {
        ZStack {
            ring(delay: 0)
            ring(delay: 1.2)
            Circle().fill(color).frame(width: size * 0.1, height: size * 0.1)
        }
        .frame(width: size, height: size)
        .onAppear { animate = true }
    }

    private func ring(delay: Double) -> some View {
        Circle().stroke(color.opacity(0.5), lineWidth: 1)
            .scaleEffect(animate ? 1.7 : 0.7)
            .opacity(animate ? 0 : 0.55)
            .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay),
                       value: animate)
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
        case .filled:  return enabled ? CT.accentInk : CT.disabledInk
        case .outline, .ghost: return CT.ink
        }
    }
    private var background: Color {
        switch style {
        case .filled:  return enabled ? CT.accent : CT.disabledFill
        case .outline: return CT.surface
        case .ghost:   return .clear
        }
    }
    @ViewBuilder private var border: some View {
        if style == .outline {
            Capsule().stroke(CT.borderStrong, lineWidth: 1)
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
                .foregroundStyle(selected ? CT.accentInk : CT.ink80)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(selected ? CT.accent : CT.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(selected ? CT.accent : CT.border, lineWidth: 1)
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
                .foregroundStyle(selected ? CT.accentInk : CT.ink80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(selected ? CT.accent : CT.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? CT.accent : CT.border, lineWidth: 1)
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
                .fill(CT.border)
                .frame(height: 1)
        }
    }
}
