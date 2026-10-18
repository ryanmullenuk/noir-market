import SwiftUI
import Observation

/// A colour scheme for the whole interface. Classic is the original red / amber / green;
/// the others take one signature colour and build the signal colours around it.
enum Palette: String, CaseIterable, Identifiable, Codable {
    case classic, blaze, imperial, mint, kiwi

    var id: String { rawValue }

    /// Every palette but Noir Terminal comes with the Full Game.
    var premium: Bool { self != .classic }

    /// The two names shown on the swatch: background, then accent.
    var names: (base: String, accent: String) {
        switch self {
        case .classic: ("Noir", "Terminal")
        case .blaze: ("Almost Black", "Blaze Orange")
        case .imperial: ("Night", "Imperial")
        case .mint: ("Carbon Black", "Electric Mint")
        case .kiwi: ("Night", "Kiwi")
        }
    }

    var baseHex: UInt32 {
        switch self {
        case .classic: 0x090909
        case .blaze: 0x070D0D
        case .imperial: 0x000F08
        case .mint: 0x141414
        case .kiwi: 0x222222
        }
    }

    /// Signature colour: the title's neon and the main buttons.
    var accentHex: UInt32 {
        switch self {
        case .classic: 0xFF4D4D
        case .blaze: 0xFF6700
        case .imperial: 0xFB3640
        case .mint: 0x2AF5C8
        case .kiwi: 0x89E900
        }
    }

    /// Positive / go colour (profits, primary buttons, good health).
    var goHex: UInt32 { self == .classic ? 0x29FF85 : accentHex }

    /// Secondary colour (travel, stash, menus, middling values): a lighter cut of the accent.
    var amberHex: UInt32 {
        switch self {
        case .classic: 0xF5BD4D
        case .blaze: 0xFFB27A
        case .imperial: 0xFF9EA3
        case .mint: 0xA6FFE9
        case .kiwi: 0xD2FF7A
        }
    }

    /// Danger / loss colour, picked to stand apart from the accent.
    var dangerHex: UInt32 {
        switch self {
        case .classic: 0xFF4D4D
        case .blaze: 0xFF3366
        case .imperial: 0xFFC145
        case .mint: 0xFF4F6E
        case .kiwi: 0xFF5A4E
        }
    }

    /// The colour shown on the swatch's lower half: Classic shows its hacker green.
    var swatchAccent: Color { self == .classic ? go : accent }

    var base: Color { Color(hex: baseHex) }
    var accent: Color { Color(hex: accentHex) }
    var go: Color { Color(hex: goHex) }
    var amber: Color { Color(hex: amberHex) }
    var danger: Color { Color(hex: dangerHex) }

    /// The background lifted towards white, for cards and panels.
    func lifted(_ amount: Double) -> Color { Color(hex: baseHex, lift: amount) }
}

extension Color {
    /// A colour from 0xRRGGBB, optionally mixed towards white by `lift` (0–1).
    init(hex: UInt32, lift: Double = 0) {
        func c(_ shift: UInt32) -> Double {
            let v = Double((hex >> shift) & 0xFF) / 255
            return v + (1 - v) * lift
        }
        self.init(red: c(16), green: c(8), blue: c(0))
    }
}

/// The live palette. Views read it through `Noir`'s colours, so Observation re-renders
/// everything that used a colour as soon as the player picks a new scheme.
@Observable
final class Theme: @unchecked Sendable {
    nonisolated(unsafe) static let shared = Theme()
    private static let key = "palette"

    var palette: Palette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: Self.key) }
    }

    private init() {
        palette = UserDefaults.standard.string(forKey: Self.key).flatMap(Palette.init(rawValue:)) ?? .classic
    }
}

/// A palette swatch in the style of a colour card: background half named in the accent,
/// accent half named in the background.
struct PaletteSwatch: View {
    let palette: Palette
    let selected: Bool
    var locked = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            half(palette.names.base.uppercased(), fill: palette.base, text: palette.swatchAccent)
            half(palette.names.accent.uppercased(), fill: palette.swatchAccent, text: palette.base)
        }
        .frame(width: 112, height: 132)
        .clipShape(shape)
        .overlay(shape.strokeBorder(selected ? palette.swatchAccent : Color.white.opacity(0.14), lineWidth: selected ? 2.5 : 1))
        .saturation(locked ? 0.55 : 1)
        .overlay(alignment: .bottomTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.7)))
                    .padding(5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.swatchAccent, palette.base)
                    .padding(7)
            }
        }
        .shadow(color: selected ? palette.swatchAccent.opacity(0.45) : .clear, radius: 10)
        .padding(6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(palette.names.accent) on \(palette.names.base)\(locked ? ", Full Game" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func half(_ name: String, fill: Color, text: Color) -> some View {
        Text(name)
            .font(Noir.title(15))
            .tracking(-0.3)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .foregroundStyle(text)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fill)
    }
}
