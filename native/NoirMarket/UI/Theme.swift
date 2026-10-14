import SwiftUI

/// Noir palette: ink blacks, silver-screen greys, one blood-red accent.
enum Noir {
    static let ink = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let coal = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let smoke = Color(red: 0.13, green: 0.13, blue: 0.145)
    static let rule = Color.white.opacity(0.12)
    static let paper = Color(red: 0.93, green: 0.91, blue: 0.86)
    static let silver = Color(red: 0.62, green: 0.62, blue: 0.64)
    static let dim = Color(red: 0.42, green: 0.42, blue: 0.45)
    static let blood = Color(red: 0.80, green: 0.14, blue: 0.16)
    static let neon = Color(red: 0.98, green: 0.24, blue: 0.27)
    static let brass = Color(red: 0.80, green: 0.67, blue: 0.42)
    static let rise = Color(red: 0.86, green: 0.84, blue: 0.78)

    /// Art Deco display face, used for titles and big numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Didot", size: size).weight(weight)
    }
    /// Typewriter face for case-file text.
    static func type(_ size: CGFloat) -> Font { .custom("AmericanTypewriter", size: size, relativeTo: .body) }
    static func typeBold(_ size: CGFloat) -> Font { .custom("AmericanTypewriter-Semibold", size: size, relativeTo: .headline) }
    /// Small tracked caps labels.
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold, design: .default) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    func noirLabel(_ size: CGFloat = 11, color: Color = Noir.dim) -> some View {
        font(Noir.label(size)).tracking(2.2).textCase(.uppercase).foregroundStyle(color)
    }

    func card(padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(Noir.coal, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Noir.rule, lineWidth: 1))
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
    enum Kind { case primary, secondary, danger, quiet }
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Noir.label(13)).tracking(2.4).textCase(.uppercase)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Noir.ink
        case .danger: Noir.paper
        case .secondary: Noir.paper
        case .quiet: Noir.silver
        }
    }
    private var background: Color {
        switch kind {
        case .primary: Noir.paper
        case .danger: Noir.blood
        case .secondary: Noir.smoke
        case .quiet: .clear
        }
    }
    private var border: Color {
        switch kind {
        case .primary: .clear
        case .danger: .clear
        case .secondary: Noir.rule
        case .quiet: Noir.rule
        }
    }
}

extension ButtonStyle where Self == NoirButtonStyle {
    static var noir: NoirButtonStyle { NoirButtonStyle() }
    static var noirPrimary: NoirButtonStyle { NoirButtonStyle(kind: .primary) }
    static var noirDanger: NoirButtonStyle { NoirButtonStyle(kind: .danger) }
    static var noirQuiet: NoirButtonStyle { NoirButtonStyle(kind: .quiet) }
}
