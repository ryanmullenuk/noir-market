import SwiftUI
import CoreText

/// Noir palette: ink blacks and silver-screen greys, lit by red / amber / green signal glows.
enum Noir {
    static let ink = Color(red: 0.035, green: 0.035, blue: 0.035)
    static let coal = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let smoke = Color(red: 0.14, green: 0.14, blue: 0.155)
    static let rule = Color.white.opacity(0.09)
    static let paper = Color(red: 0.92, green: 0.93, blue: 0.92)
    static let silver = Color(red: 0.66, green: 0.66, blue: 0.69)
    static let dim = Color(red: 0.44, green: 0.44, blue: 0.47)
    static let blood = Color(red: 0.80, green: 0.14, blue: 0.16)
    static let neon = Color(red: 1.0, green: 0.30, blue: 0.30)
    static let brass = Color(red: 0.96, green: 0.74, blue: 0.30)
    static let go = Color(red: 0.16, green: 1.0, blue: 0.52)
    static let rise = go

    // RAG signal colours.
    static let red = neon
    static let amber = brass
    static let green = go

    /// Red / amber / green for a 0–100 value where high is good (health) or bad (heat).
    static func rag(_ value: Int, highIsGood: Bool) -> Color {
        let v = highIsGood ? value : 100 - value
        return v <= 30 ? red : v <= 65 ? amber : green
    }

    static let radius: CGFloat = 18

    /// Space Grotesk for display headings.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name = weight == .regular || weight == .light ? "SpaceGrotesk-Regular" : weight == .medium ? "SpaceGrotesk-Medium" : "SpaceGrotesk-Bold"
        return .custom(name, size: size, relativeTo: .title)
    }
    /// Mona Sans Black for the title lockup.
    static func title(_ size: CGFloat, expanded: Bool = false) -> Font {
        .custom(expanded ? "MonaSansExpanded-Black" : "MonaSans-Black", size: size)
    }
    /// JetBrains Mono for everything else.
    static func monoName(_ weight: Font.Weight) -> String {
        switch weight {
        case .heavy, .black: "JetBrainsMono-ExtraBold"
        case .bold: "JetBrainsMono-Bold"
        case .semibold: "JetBrainsMono-SemiBold"
        case .medium: "JetBrainsMono-Medium"
        default: "JetBrainsMono-Regular"
        }
    }
    static func type(_ size: CGFloat) -> Font { .custom(monoName(.regular), size: size, relativeTo: .body) }
    static func typeBold(_ size: CGFloat) -> Font { .custom(monoName(.bold), size: size, relativeTo: .headline) }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .custom(monoName(weight), size: size, relativeTo: .body) }
    /// Small tracked caps labels.
    static func label(_ size: CGFloat = 11) -> Font { .custom(monoName(.bold), size: size, relativeTo: .caption) }
    /// Figures.
    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { .custom(monoName(weight), size: size, relativeTo: .body) }

    /// Registers the bundled fonts. Called once at launch.
    static func registerFonts() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension View {
    func noirLabel(_ size: CGFloat = 11, color: Color = Noir.dim) -> some View {
        font(Noir.label(size)).tracking(1.2).textCase(.uppercase).foregroundStyle(color)
    }

    /// Rounded glassy panel.
    func card(padding: CGFloat = 16, radius: CGFloat = Noir.radius, tint: Color? = nil) -> some View {
        self.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.105), Color(white: 0.06)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        }
                    }
            }
            .overlay {
                // Only tinted cards get an outline; plain cards sit on the black without a ring.
                if let tint {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
            }
    }

    /// Soft neon glow in a signal colour.
    func glow(_ color: Color, radius: CGFloat = 10, intensity: Double = 0.55) -> some View {
        shadow(color: color.opacity(intensity), radius: radius / 2)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius)
    }
}

/// A glowing circular badge for an SF Symbol.
struct GlowIcon: View {
    let symbol: String
    var color: Color = Noir.silver
    var size: CGFloat = 34
    var lit = true

    var body: some View {
        SymbolImage(name: symbol, size: size * 0.44)
            .foregroundStyle(lit ? color : Noir.silver)
            .frame(width: size, height: size)
            .background {
                if lit {
                    Circle().fill(RadialGradient(colors: [color.opacity(0.28), color.opacity(0.04)],
                                                 center: .center, startRadius: 1, endRadius: size * 0.6))
                }
            }
            .overlay { if lit { Circle().strokeBorder(color.opacity(0.55), lineWidth: 1) } }
            .shadow(color: lit ? color.opacity(0.5) : .clear, radius: 8)
    }
}

/// Film grain + vignette laid over every screen.
struct FilmGrain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 3600 : 1.0 / 12)) { context in
            Canvas { ctx, size in
                var rng = SplitMix(seed: UInt64(context.date.timeIntervalSinceReferenceDate * 12))
                for _ in 0..<220 {
                    let x = Double(rng.next() % 10_000) / 10_000 * size.width
                    let y = Double(rng.next() % 10_000) / 10_000 * size.height
                    let a = Double(rng.next() % 100) / 100 * 0.07
                    ctx.fill(Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.white.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
        .overlay(
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 180, endRadius: 620)
                .allowsHitTesting(false)
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Slanted rain over a scene. Cheap: one Canvas, ~140 streaks.
struct Rain: View {
    var intensity: Int = 140
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Canvas { ctx, size in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                var rng = SplitMix(seed: 7)
                for _ in 0..<intensity {
                    let x0 = Double(rng.next() % 10_000) / 10_000 * (size.width + 120)
                    let speed = 700 + Double(rng.next() % 500)
                    let phase = Double(rng.next() % 10_000) / 10_000
                    let len = 14 + Double(rng.next() % 22)
                    let alpha = 0.08 + Double(rng.next() % 100) / 100 * 0.22
                    let travel = size.height + 80
                    let y = (phase * travel + t * speed).truncatingRemainder(dividingBy: travel) - 40
                    let x = x0 - y * 0.18
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
                    ctx.stroke(p, with: .color(.white.opacity(alpha)), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct NoirButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger, quiet, amber }
    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        configuration.label
            .font(Noir.label(13)).tracking(1.4).textCase(.uppercase)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(foreground)
            .background {
                shape.fill(LinearGradient(colors: [tint.opacity(fillTop), tint.opacity(fillBottom)], startPoint: .top, endPoint: .bottom))
            }
            .overlay { shape.strokeBorder(stroke, lineWidth: 1.2) }
            .shadow(color: glowing ? tint.opacity(configuration.isPressed ? 0.7 : 0.38) : .clear, radius: configuration.isPressed ? 14 : 9)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }

    private var glowing: Bool { enabled && (kind == .primary || kind == .danger || kind == .amber) }

    private var tint: Color {
        switch kind {
        case .primary: Noir.green
        case .danger: Noir.red
        case .amber: Noir.amber
        case .secondary: .white
        case .quiet: .white
        }
    }
    private var fillTop: Double {
        switch kind {
        case .primary, .danger, .amber: 0.22
        case .secondary: 0.09
        case .quiet: 0.03
        }
    }
    private var fillBottom: Double {
        switch kind {
        case .primary, .danger, .amber: 0.06
        case .secondary: 0.04
        case .quiet: 0.0
        }
    }
    private var stroke: Color {
        switch kind {
        case .primary, .danger, .amber: tint.opacity(0.85)
        case .secondary: .clear
        case .quiet: .clear
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary, .danger, .amber: tint
        case .secondary: Noir.paper
        case .quiet: Noir.silver
        }
    }
}

extension ButtonStyle where Self == NoirButtonStyle {
    static var noir: NoirButtonStyle { NoirButtonStyle() }
    static var noirPrimary: NoirButtonStyle { NoirButtonStyle(kind: .primary) }
    static var noirDanger: NoirButtonStyle { NoirButtonStyle(kind: .danger) }
    static var noirQuiet: NoirButtonStyle { NoirButtonStyle(kind: .quiet) }
    static var noirAmber: NoirButtonStyle { NoirButtonStyle(kind: .amber) }
}

/// SF Symbol, or one of our own drawn icons for things SF Symbols doesn't have.
struct SymbolImage: View {
    let name: String
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold

    var body: some View {
        if name == "custom.mushroom" {
            MushroomShape()
                .fill(style: FillStyle(eoFill: true))
                .frame(width: size * 1.15, height: size * 1.15)
        } else {
            Image(systemName: name).font(.system(size: size, weight: weight))
        }
    }
}

/// A spotted mushroom: domed cap with cut-out spots over a short stem.
struct MushroomShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width / 100, h = rect.height / 100
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        var p = Path()
        // Cap.
        p.move(to: pt(4, 56))
        p.addCurve(to: pt(50, 8), control1: pt(4, 26), control2: pt(26, 8))
        p.addCurve(to: pt(96, 56), control1: pt(74, 8), control2: pt(96, 26))
        p.addQuadCurve(to: pt(4, 56), control: pt(50, 66))
        p.closeSubpath()
        // Spots, cut out of the cap.
        for (x, y, r) in [(30.0, 34.0, 8.0), (56.0, 22.0, 6.5), (74.0, 42.0, 6.0), (48.0, 46.0, 5.0)] {
            p.addEllipse(in: CGRect(x: rect.minX + (x - r) * w, y: rect.minY + (y - r) * h, width: r * 2 * w, height: r * 2 * h))
        }
        // Stem, slightly flared at the base.
        var stem = Path()
        stem.move(to: pt(38, 64))
        stem.addLine(to: pt(62, 64))
        stem.addQuadCurve(to: pt(66, 92), control: pt(62, 80))
        stem.addQuadCurve(to: pt(34, 92), control: pt(50, 97))
        stem.addQuadCurve(to: pt(38, 64), control: pt(38, 80))
        stem.closeSubpath()
        p.addPath(stem)
        return p
    }
}
