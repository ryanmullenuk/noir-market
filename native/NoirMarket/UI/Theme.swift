import SwiftUI

/// Noir palette: ink blacks and silver-screen greys, lit by red / amber / green signal glows.
enum Noir {
    static let ink = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let coal = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let smoke = Color(red: 0.14, green: 0.14, blue: 0.155)
    static let rule = Color.white.opacity(0.09)
    static let paper = Color(red: 0.95, green: 0.94, blue: 0.91)
    static let silver = Color(red: 0.66, green: 0.66, blue: 0.69)
    static let dim = Color(red: 0.44, green: 0.44, blue: 0.47)
    static let blood = Color(red: 0.80, green: 0.14, blue: 0.16)
    static let neon = Color(red: 1.0, green: 0.30, blue: 0.30)
    static let brass = Color(red: 0.96, green: 0.74, blue: 0.30)
    static let go = Color(red: 0.32, green: 0.88, blue: 0.42)
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

    /// Art Deco display face, used for titles and big numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Didot", size: size).weight(weight)
    }
    /// Typewriter face for flavour text and the newspaper.
    static func type(_ size: CGFloat) -> Font { .custom("AmericanTypewriter", size: size, relativeTo: .body) }
    static func typeBold(_ size: CGFloat) -> Font { .custom("AmericanTypewriter-Semibold", size: size, relativeTo: .headline) }
    /// Clean UI text.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .default) }
    /// Small tracked caps labels.
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold, design: .default) }
    /// Figures: rounded, tabular.
    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension View {
    func noirLabel(_ size: CGFloat = 11, color: Color = Noir.dim) -> some View {
        font(Noir.label(size)).tracking(1.8).textCase(.uppercase).foregroundStyle(color)
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
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [(tint ?? .white).opacity(tint == nil ? 0.13 : 0.45), (tint ?? .white).opacity(0.04)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
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
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(lit ? color : Noir.silver)
            .frame(width: size, height: size)
            .background {
                Circle().fill(RadialGradient(colors: [(lit ? color : .white).opacity(lit ? 0.28 : 0.06), (lit ? color : .white).opacity(0.04)],
                                             center: .center, startRadius: 1, endRadius: size * 0.6))
            }
            .overlay(Circle().strokeBorder((lit ? color : .white).opacity(lit ? 0.55 : 0.1), lineWidth: 1))
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
            .font(Noir.label(13)).tracking(2).textCase(.uppercase)
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
        case .secondary: .white.opacity(0.14)
        case .quiet: .white.opacity(0.1)
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
