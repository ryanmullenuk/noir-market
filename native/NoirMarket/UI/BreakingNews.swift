import SwiftUI

/// Neon-yellow Breaking News tip-off: the police are about to raid the city you're in.
/// Always yellow, whatever the palette, so it can't be mistaken for anything else.
struct BreakingNewsView: View {
    let raid: RaidAlert
    var onTravel: () -> Void

    @Environment(GameStore.self) private var store
    @State private var blink = false
    @State private var shown = false

    static let yellow = Color(hex: 0xFFE600)

    var body: some View {
        let yellow = Self.yellow
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            if let s = store.state {
                VStack(alignment: .leading, spacing: 0) {
                    banner
                    VStack(alignment: .leading, spacing: 14) {
                        Text("RAID EXPECTED IN \(Catalog.cities[raid.city].name.uppercased())")
                            .font(Noir.display(24)).foregroundStyle(yellow)
                            .shadow(color: yellow.opacity(0.5), radius: 10)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(story(s))
                            .font(Noir.type(14)).foregroundStyle(Noir.paper)
                            .fixedSize(horizontal: false, vertical: true)
                        exposure(s)
                        Text("Stash it and you’ve nothing for them to find. Better still, keep moving: the longer you sit in one city, the more people know where you sleep.")
                            .font(Noir.ui(12)).foregroundStyle(Noir.silver)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 10) {
                            Button {
                                Audio.shared.play(.thud, volume: 0.5)
                                Audio.shared.buzz(.success)
                                store.act { Engine.goToGround(&$0) }
                            } label: {
                                Label("Stash everything in the lock-up", systemImage: "lock.fill")
                            }
                            .buttonStyle(YellowButton(filled: true))
                            Button {
                                Audio.shared.play(.click, volume: 0.5)
                                store.act { $0.raid?.seen = true }
                                onTravel()
                            } label: {
                                Label("Get out of town", systemImage: "tram.fill")
                            }
                            .buttonStyle(YellowButton(filled: false))
                            Button("Chance it") {
                                Audio.shared.play(.click, volume: 0.4)
                                store.act { $0.raid?.seen = true }
                            }
                            .buttonStyle(.noirQuiet)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0x0B0B05)))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(yellow.opacity(blink ? 1 : 0.6), lineWidth: 1.6))
                .shadow(color: yellow.opacity(blink ? 0.55 : 0.25), radius: 26)
                .padding(.horizontal, 20)
                .scaleEffect(shown ? 1 : 0.9)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            Audio.shared.play(.siren, volume: 0.5)
            Audio.shared.buzz(.danger)
            withAnimation(.spring(duration: 0.35)) { shown = true }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { blink = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    /// Flashing hazard-striped header.
    private var banner: some View {
        HStack(spacing: 10) {
            Image(systemName: "light.beacon.max.fill").font(.system(size: 18, weight: .bold))
            Text("BREAKING NEWS").font(Noir.title(22)).tracking(0.5)
            Spacer()
            Text("LIVE").font(Noir.label(11)).tracking(1.5)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(Color.black))
                .foregroundStyle(Self.yellow)
                .opacity(blink ? 1 : 0.3)
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Self.yellow.opacity(blink ? 1 : 0.85))
        .overlay(alignment: .bottom) { HazardStripes().frame(height: 6) }
    }

    private func story(_ s: GameState) -> String {
        let city = Catalog.cities[raid.city].name
        let nights = s.streak ?? 0
        let lead = nights >= Engine.raidStreak
            ? "You’ve slept in \(city) \(nights) nights running. People have noticed. "
            : "Somebody’s been talking. "
        return lead + "Unmarked cars are circling, and a source says a warrant for your door goes out tonight. Stay here tonight and they will very likely come for you."
    }

    @ViewBuilder
    private func exposure(_ s: GameState) -> some View {
        let units = Engine.carried(s)
        let guns = Catalog.weapons.filter { s.weapons[$0.id] > 0 }.map(\.name)
        let room = Engine.vaultCapacity(s, s.city) - Engine.vaultUsed(s, s.city)
        VStack(alignment: .leading, spacing: 6) {
            line("bag.fill", units > 0 ? "\(units) units on you" : "No stock on you", hot: units > 0)
            line("scope", guns.isEmpty ? "No weapons on you" : guns.joined(separator: ", "), hot: !guns.isEmpty)
            line("lock.fill", "Lock-up has room for \(room) units", hot: units > room)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    private func line(_ symbol: String, _ text: String, hot: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).frame(width: 16)
            Text(text).font(Noir.ui(12, weight: .semibold))
        }
        .foregroundStyle(hot ? Self.yellow : Noir.silver)
    }
}

private struct HazardStripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BreakingNewsView.yellow))
            var x = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height * 2, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(.black))
                x += size.height * 3
            }
        }
    }
}

private struct YellowButton: ButtonStyle {
    let filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let y = BreakingNewsView.yellow
        configuration.label
            .font(Noir.label(13)).tracking(1.2).textCase(.uppercase)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(filled ? Color.black : y)
            .background(shape.fill(filled ? y : y.opacity(0.08)))
            .overlay(shape.strokeBorder(y, lineWidth: 1.2))
            .shadow(color: y.opacity(configuration.isPressed ? 0.7 : 0.35), radius: configuration.isPressed ? 14 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// What each street stat is, and what it does to your game.
enum StatHelp: String, Identifiable {
    case health, heat, respect
    var id: String { rawValue }

    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .health: "heart.fill"
        case .heat: "flame.fill"
        case .respect: "star.fill"
        }
    }
    var highIsGood: Bool { self != .heat }

    func value(_ s: GameState) -> Int {
        switch self {
        case .health: s.health
        case .heat: s.heat
        case .respect: s.rep
        }
    }

    func text(_ s: GameState) -> String {
        let v = value(s)
        switch self {
        case .health:
            let now = v <= 30 ? "You’re in a bad way. One more beating could finish you." : v <= 65 ? "You’ve taken some knocks." : "You’re in one piece."
            return "How much punishment you can still take. Fights, muggings and failed escapes knock it down, and at zero the game is over.\n\nThe doctor in Market patches you up, for a price.\n\n\(now)"
        case .heat:
            let now = v <= 30 ? "They barely know your name." : v <= 65 ? "You’re on their radar." : "They’re looking for you. Expect stops."
            return "How hard the police are looking for you. It climbs while you carry stock or weapons, and cools on quiet, clean nights or when you lie low.\n\nHigh heat means more stops, bigger bribes and less chance a bribe works.\n\n\(now)"
        case .respect:
            let now = v <= 30 ? "Nobody’s scared of you yet." : v <= 65 ? "People know who you are." : "The street steps aside."
            return "Your name on the street. Trading builds it; getting nicked or a bribe that backfires costs it.\n\nHigh respect means fewer muggings, better odds with a bribe and more favours from friends.\n\n\(now)"
        }
    }
}
