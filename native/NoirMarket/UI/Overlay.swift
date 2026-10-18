import SwiftUI

/// Full-screen beats between days: the morning paper, then any trouble, then the result.
struct Overlay: View {
    var onQuit: () -> Void
    var onNewGame: () -> Void = {}
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            if let s = store.state {
                if let report = s.report {
                    Newspaper(report: report, s: s) {
                        withAnimation(.easeInOut(duration: 0.35)) { store.clearReport() }
                    }
                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                } else if let outcome = s.outcome {
                    OutcomeView(outcome: outcome) {
                        withAnimation(.easeInOut(duration: 0.3)) { store.clearOutcome() }
                    }
                    .transition(.opacity)
                } else if let encounter = s.encounters.first {
                    EncounterView(encounter: encounter, s: s)
                        .transition(.opacity)
                } else if s.pendingEnding == true {
                    EndingChoice(s: s)
                        .transition(.opacity)
                } else if let over = s.over {
                    CaseClosed(over: over, s: s, onDone: onQuit, onNewGame: onNewGame)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.state?.report)
        .animation(.easeInOut(duration: 0.3), value: store.state?.outcome)
    }
}

// MARK: NOIRNET, the underground wire

/// The morning report as an encrypted terminal feed, typed out fast with a block cursor.
private struct Newspaper: View {
    let report: DayReport
    let s: GameState
    var onDone: () -> Void

    struct Line: Identifiable {
        let id: Int
        let tag: String
        let text: String
        let colour: Color
    }

    @State private var typed = 0
    @State private var cursorOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lines: [Line] {
        var out: [Line] = []
        var n = 0
        func add(_ tag: String, _ text: String, _ c: Color) { out.append(Line(id: n, tag: tag, text: text, colour: c)); n += 1 }
        let node = Catalog.cities[report.city].name.uppercased()
        add(">", "noirnet relay v2.7 :: handshake ok :: cipher aes-256", Noir.dim)
        add(">", "node \(node) :: day \(String(format: "%02d", report.day))/\(s.maxDay) :: \(report.travelled ? "new location" : "same location")", Noir.dim)
        let voice = Press.cityVoice[Catalog.cities[report.city].name] ?? []
        if !voice.isEmpty { add("LOCAL", voice[report.day % voice.count], Noir.paper) }
        if let w = s.weather {
            let line = w == "rain" ? "rain all night. coppers hate getting wet: fewer stops." : w == "fog" ? "thick fog. good for hiding, better for muggers." : "clear skies. nowhere to hide."
            add("WEATHER", line, Noir.silver)
        }
        for check in report.checks ?? [] {
            let good = check.hasPrefix("CONFIRMED") || check.hasPrefix("TIP PAID")
            add(good ? "VERIFIED" : "DEBUNKED", check, good ? Noir.green : Noir.red)
        }
        add("INTEL", "\(report.story)  [unverified]", Noir.amber)
        for line in s.ticker {
            let parts = line.split(separator: ".", maxSplits: 1).map(String.init)
            add("WIRE", parts.count > 1 ? "\(parts[0]) // \(parts[1].trimmingCharacters(in: .whitespaces))" : line, Noir.green)
        }
        for line in report.lines { add("YOU", line, Noir.paper) }
        if !s.encounters.isEmpty {
            add("ALERT", "movement detected near your position. respond now.", Noir.red)
        }
        add(">", "end of transmission", Noir.dim)
        return out
    }

    private var total: Int { lines.reduce(0) { $0 + $1.tag.count + $1.text.count + 3 } }

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            // Faint green phosphor wash and scanlines.
            RadialGradient(colors: [Noir.green.opacity(0.10), .clear], center: .center, startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
            Scanlines().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Noir.green).frame(width: 8, height: 8).glow(Noir.green, radius: 6)
                    Text("NOIRNET").font(Noir.display(22)).foregroundStyle(Noir.green)
                    Text("// SECURE CHANNEL").font(Noir.label(10)).tracking(1.2).foregroundStyle(Noir.green.opacity(0.7))
                    Spacer()
                    Text("DAY \(String(format: "%02d", report.day))").font(Noir.label(11)).foregroundStyle(Noir.green)
                }
                .padding(.bottom, 12)
                Rectangle().fill(Noir.green.opacity(0.35)).frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(visible) { line in
                                (Text(line.tag == ">" ? "> " : "[\(line.tag)] ").foregroundStyle(line.colour.opacity(0.95))
                                 + Text(line.text).foregroundStyle(line.tag == ">" ? Noir.dim : Noir.paper.opacity(line.tag == "WIRE" ? 0.85 : 1))
                                 + Text(line.id == lastVisibleID && typed < total ? (cursorOn ? "█" : " ") : "").foregroundStyle(Noir.green))
                                    .font(Noir.ui(14))
                                    .lineSpacing(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                            if typed >= total {
                                Text(cursorOn ? "█" : " ").font(Noir.ui(14)).foregroundStyle(Noir.green).id(-1)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: typed) { proxy.scrollTo(typed >= total ? -1 : lastVisibleID, anchor: .bottom) }
                }

                Button(s.encounters.isEmpty ? "Disconnect" : "Respond") {
                    Audio.shared.play(.click, volume: 0.7)
                    Audio.shared.buzz(s.encounters.isEmpty ? .tap : .warning)
                    onDone()
                }
                .buttonStyle(s.encounters.isEmpty ? NoirButtonStyle(kind: .primary) : NoirButtonStyle(kind: .danger))
                .opacity(typed >= total ? 1 : 0.35)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture { typed = total }
        .onAppear { Audio.shared.play(.click, volume: 0.7) }
        .task {
            if reduceMotion { typed = total; return }
            while typed < total {
                try? await Task.sleep(for: .milliseconds(12))
                typed = min(total, typed + 5)
                if typed % 40 < 5 { Audio.shared.play(.key, volume: 0.12) }
                if typed % 15 < 5 { Audio.shared.typeTick() }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                cursorOn.toggle()
            }
        }
    }

    /// Lines typed so far, with the last one cut at the current character.
    private var visible: [Line] {
        var left = typed
        var out: [Line] = []
        for line in lines {
            let len = line.tag.count + line.text.count + 3
            if left <= 0 { break }
            if left >= len { out.append(line) } else {
                out.append(Line(id: line.id, tag: line.tag, text: String(line.text.prefix(max(0, left - line.tag.count - 3))), colour: line.colour))
            }
            left -= len
        }
        return out
    }

    private var lastVisibleID: Int { visible.last?.id ?? 0 }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y = 0.0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.025)))
                y += 3
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: Encounters

private struct EncounterView: View {
    let encounter: Encounter
    let s: GameState
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            backdrop
            Rain(intensity: 90)
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                Text(kicker).noirLabel(12, color: Noir.neon)
                Text(title).font(Noir.display(44)).foregroundStyle(Noir.paper)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text).font(Noir.type(16)).foregroundStyle(Noir.silver)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Meter(label: "Health", symbol: "heart.fill", value: s.health, colour: Noir.rag(s.health, highIsGood: true))
                }
                .padding(.vertical, 6)
                VStack(spacing: 10) {
                    ForEach(options, id: \.choice) { o in
                        Button {
                            choose(o.choice)
                        } label: {
                            HStack {
                                Text(o.label)
                                Spacer()
                                if let odds = o.odds {
                                    let c = odds >= 0.6 ? Noir.green : odds >= 0.35 ? Noir.amber : Noir.red
                                    Text("\(Int((odds * 100).rounded()))%")
                                        .font(Noir.mono(13))
                                        .foregroundStyle(c)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Capsule().fill(c.opacity(0.15)))
                                        .shadow(color: c.opacity(0.5), radius: 5)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(NoirButtonStyle(kind: o.primary ? .primary : o.danger ? .danger : .secondary))
                        .disabled(!o.enabled)
                        if let note = o.note {
                            Text(note).font(Noir.ui(11)).foregroundStyle(Noir.dim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, -6)
                        }
                    }
                }
            }
            .padding(24)
            FilmGrain()
        }
        .onAppear {
            Audio.shared.buzz(.danger)
            switch encounter {
            case .police: Audio.shared.play(.siren, volume: 0.35)
            case .collector: Audio.shared.play(.knuckles, volume: 0.8)
            case .trouble: Audio.shared.play(.thud)
            }
        }
    }

    @ViewBuilder private var backdrop: some View {
        switch encounter {
        case .police: PoliceLights()
        case .collector: TorchGlare()
        case .trouble(let t): StreetLamp(figures: t.attacker + 1)
        }
    }

    private var kicker: String {
        switch encounter {
        case .police(let p): (p.round ?? 1) > 1 ? "Shots fired" : p.grass != nil ? "Sold out" : p.raid == true ? "Raid" : p.depot == true ? "At the depot" : p.airport ? "Arrivals hall" : "Blue lights"
        case .trouble(let t): t.round > 1 ? "Round \(t.round)" : t.crew != nil ? "Their turf" : "A dark street"
        case .collector: "A knock at the door"
        }
    }

    private var title: String {
        switch encounter {
        case .police(let p): p.airport ? "Customs" : "Police Stop"
        case .trouble(let t): t.crew ?? "Trouble"
        case .collector(let c): "\(lenderName(c))’s Lads"
        }
    }

    /// Unarmed? Show what a weapon would do for the odds, so the Black Market makes sense.
    private func fightNote(_ t: Trouble, armed: Bool) -> String {
        guard !armed, t.round == 1 else { return "Miss and they hit back." }
        let machete = Catalog.weapons[2]
        var odds = t.attacker == 0 ? 0.75 : min(0.96, 0.10 + machete.win)
        if t.attacker == 4 { odds *= 0.8 }
        return "Miss and they hit back. With a \(machete.name.lowercased()) it’d be \(Int((odds * 100).rounded()))%. The Black Market sells them."
    }

    private var text: String {
        let units = Engine.carried(s)
        switch encounter {
        case .police(let p):
            let what = units > 0 ? "\(units) units in your bag" : "nothing in your pockets but nerves"
            return (p.grass != nil ? "They know your name, your city and what’s in your bag. \(p.grass!) has been talking. "
                    : p.raid == true ? "4 a.m. The door comes off its hinges. Torches, shouting, a warrant with your name spelled wrong. The tip-off was right. "
                    : p.depot == true ? "Two plain-clothes officers step out from behind the shipping crates. They were expecting you. "
                    : p.airport ? "A customs officer with tired eyes points at your bag. " : "A patrol car pulls up and two officers get out slowly. ")
                + "You’ve got \(what)." + (Engine.hasWeapons(s) ? " And something heavier under your coat." : "")
        case .trouble(let t):
            let a = Catalog.attackers[t.attacker]
            if let crew = t.crew, t.round == 1 {
                return "The \(crew) step out of a parked car. You’ve been selling on their streets, and they want their cut. All of it."
            }
            return t.round > 1 ? "They’re still coming." : "You’re cornered by \(a.name). They want your money, and they’re not asking twice."
        case .collector(let c):
            return "\(lenderName(c)) wants \(Money.gbp(c.owed)), and it’s overdue. His lads are cracking their knuckles in a way that feels rehearsed."
        }
    }

    private func lenderName(_ c: Collector) -> String {
        s.loans.first { $0.id == c.loan }.map { Catalog.lenders[$0.lender].name } ?? "The lender"
    }

    struct Option {
        var choice: Choice
        var label: String
        var odds: Double?
        var note: String?
        var enabled = true
        var primary = false
        var danger = false
    }

    private var options: [Option] {
        let weapon = Engine.bestWeapon(s)
        switch encounter {
        case .police(let p):
            if (p.round ?? 1) > 1 {
                // Shots have been fired: no more bribes.
                return [
                    Option(choice: .fight, label: weapon.map { WeaponKind($0) == .gun ? "Fire again" : "Go again with the \($0.name.lowercased())" } ?? "Swing again",
                           odds: p.fightChance, note: "Miss again and it’s over.", danger: true),
                    Option(choice: .run, label: "Run", odds: p.runChance, note: "They’re angry now.", primary: true),
                    Option(choice: .comply, label: "Give up", note: "Lose what you carry, a fine, and extra nights in a cell for the trouble."),
                ]
            }
            var list = [
                Option(choice: .bribe, label: "Offer \(Money.gbp(p.bribe))", odds: p.bribeChance,
                       note: s.cash < p.bribe ? "You haven’t got that on you." : "If he says no, you’re nicked anyway.",
                       enabled: s.cash >= p.bribe, primary: true),
            ]
            if Engine.carried(s) > 0 {
                list.append(Option(choice: .handOver, label: "Let them “lose” half", odds: 1, note: "Half your stock disappears into the patrol car. No paperwork."))
            }
            list.append(Option(choice: .run, label: "Run", odds: p.runChance, note: "Get caught and you’ll be hurt and nicked."))
            list.append(Option(choice: .comply, label: "Go quietly",
                               note: Engine.carried(s) == 0 && !Engine.hasWeapons(s) ? "You’re clean. Probably fine."
                                   : "Lose everything you carry and pay a fine" + (p.jail > 0 ? ", plus a few nights in a cell." : ".")))
            if let weapon {
                list.append(Option(choice: .fight, label: "Pull the \(weapon.name.lowercased())", odds: p.fightChance, note: "Huge heat if it works. If you miss, they fire back.", danger: true))
            }
            return list
        case .trouble(let t):
            let again = t.round > 1
            return [
                Option(choice: .run, label: "Run", odds: t.runChance, primary: true),
                Option(choice: .fight, label: again ? (weapon.map { WeaponKind($0) == .gun ? "Fire again" : "Fight on" } ?? "Swing again")
                                                    : (weapon.map { "Fight with the \($0.name.lowercased())" } ?? "Fight with your fists"),
                       odds: t.fightChance, note: fightNote(t, armed: weapon != nil), danger: true),
                Option(choice: .handOver, label: (again ? "Give up · " : t.crew != nil ? "Pay the rent · " : "Hand over ") + Money.gbp(min(s.cash, t.handOver)),
                       note: again ? "They take extra for the trouble." : t.attacker >= 2 ? "They’ll take some stock too." : "Nobody gets hurt."),
            ]
        case .collector(let c):
            let owed = s.loans.first { $0.id == c.loan }.map { Engine.payoff($0, day: s.day) } ?? c.owed
            return [
                Option(choice: .pay, label: s.cash >= owed ? "Pay \(Money.gbp(owed))" : "Give them \(Money.gbp(s.cash))",
                       note: s.cash >= owed ? "Clears the debt." : "Buys two more days for the rest.", enabled: s.cash > 0, primary: true),
                Option(choice: .beating, label: "Take the beating", note: "10–25% health, and two days’ grace.", danger: true),
            ]
        }
    }

    private func choose(_ c: Choice) {
        let health = s.health
        if c == .fight {
            switch WeaponKind(Engine.bestWeapon(s)) {
            case .gun: Audio.shared.play(.gunshot, volume: 0.8)
            case .blade: Audio.shared.play(.swipe, volume: 0.8)
            case .explosive: Audio.shared.play(.boom, volume: 0.8)
            case .fists: Audio.shared.play(.thud, volume: 0.8)
            }
        }
        if c == .beating { Audio.shared.play(.knuckles, volume: 0.8) }
        store.act { try Engine.resolve(&$0, c) }
        if let o = store.state?.outcome { Audio.shared.buzz(o.good ? .success : .danger) }
        if (store.state?.health ?? health) < health { Audio.shared.play(.thud, volume: 0.8) }
    }
}

/// A torch shone straight in your eyes: a hot white bloom that drifts and flares.
private struct TorchGlare: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let x = 0.5 + sin(t * 0.7) * 0.12 + sin(t * 1.9) * 0.03
            let y = 0.28 + cos(t * 0.9) * 0.05
            let flare = 0.85 + sin(t * 9) * 0.04 + (sin(t * 0.5) > 0.97 ? 0.15 : 0)
            GeometryReader { geo in
                ZStack {
                    RadialGradient(colors: [Color.white.opacity(0.55 * flare), Color(red: 1, green: 0.95, blue: 0.85).opacity(0.18), .clear],
                                   center: UnitPoint(x: x, y: y), startRadius: 4, endRadius: geo.size.width * 0.75)
                    // Horizontal lens streak through the hot spot.
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.22 * flare), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 1.4, height: 6)
                        .blur(radius: 3)
                        .position(x: geo.size.width * x, y: geo.size.height * y)
                    Circle().fill(.white.opacity(0.9 * flare)).frame(width: 26, height: 26).blur(radius: 6)
                        .position(x: geo.size.width * x, y: geo.size.height * y)
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PoliceLights: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.2 : nil)) { ctx in
            let t = reduceMotion ? floor(ctx.date.timeIntervalSinceReferenceDate / 1.2) * 0.45 : ctx.date.timeIntervalSinceReferenceDate
            let red = (sin(t * 7) + 1) / 2
            ZStack {
                RadialGradient(colors: [Color(red: 0.9, green: 0.1, blue: 0.15).opacity(0.55 * red), .clear],
                               center: .topLeading, startRadius: 10, endRadius: 420)
                RadialGradient(colors: [Color(red: 0.15, green: 0.3, blue: 1).opacity(0.55 * (1 - red)), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

/// A lone street lamp in the rain: soft volumetric cone, drifting dust, wet-road reflection,
/// low fog, and silhouettes waiting at the edge of the light.
private struct StreetLamp: View {
    var figures: Int = 2
    @State private var flicker = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let lampX = w * 0.7, lampY = h * 0.09, ground = h * 0.37
            ZStack {
                LinearGradient(colors: [Color(red: 0.03, green: 0.035, blue: 0.06), .black], startPoint: .top, endPoint: .init(x: 0.5, y: 0.6))

                // Light cone, blurred so its edges fall off softly.
                Path { p in
                    p.move(to: CGPoint(x: lampX - 10, y: lampY))
                    p.addLine(to: CGPoint(x: lampX + 10, y: lampY))
                    p.addLine(to: CGPoint(x: lampX + w * 0.38, y: ground))
                    p.addLine(to: CGPoint(x: lampX - w * 0.42, y: ground))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.55).opacity(0.32 * flicker), Color(red: 1, green: 0.8, blue: 0.5).opacity(0.05)],
                                     startPoint: .top, endPoint: .bottom))
                .blur(radius: 12)

                // Pool of light on the wet road and the lamp's long reflection.
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.85, blue: 0.6).opacity(0.3 * flicker), .clear], center: .center, startRadius: 2, endRadius: w * 0.4))
                    .frame(width: w * 0.95, height: h * 0.07)
                    .position(x: lampX - w * 0.04, y: ground)
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.6).opacity(0.28 * flicker), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 14, height: h * 0.14)
                    .blur(radius: 6)
                    .position(x: lampX, y: ground + h * 0.08)

                Dust(lampX: lampX, lampY: lampY, size: CGSize(width: w, height: ground / 0.74))
                    .opacity(flicker)

                // Silhouettes waiting at the edge of the light, feet on the road.
                ForEach(0..<figures, id: \.self) { i in
                    let fh = h * (0.12 - Double(i % 2) * 0.01)
                    Image(systemName: i % 2 == 0 ? "figure.stand" : "figure.walk")
                        .resizable().scaledToFit()
                        .frame(height: fh)
                        .foregroundStyle(Color.black)
                        .shadow(color: Color(red: 1, green: 0.8, blue: 0.5).opacity(0.45 * flicker), radius: 0.8, x: 1.5, y: 0)
                        .position(x: w * (0.2 + Double(i) * 0.11), y: ground - fh / 2 + 2)
                }

                // Low fog drifting across the road.
                Fog().frame(height: h * 0.14).position(x: w / 2, y: ground - h * 0.02)

                // Lamp post and head with a warm halo.
                Path { p in
                    p.move(to: CGPoint(x: lampX, y: lampY - 4))
                    p.addLine(to: CGPoint(x: lampX, y: lampY - 24))
                    p.addLine(to: CGPoint(x: lampX + 48, y: lampY - 24))
                    p.addLine(to: CGPoint(x: lampX + 48, y: ground))
                }
                .stroke(Color(white: 0.13), lineWidth: 5)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.9, blue: 0.7).opacity(0.55 * flicker), .clear], center: .center, startRadius: 2, endRadius: 70))
                    .frame(width: 140, height: 140)
                    .position(x: lampX, y: lampY)
                Capsule().fill(Color(white: 0.18)).frame(width: 30, height: 9).position(x: lampX, y: lampY - 4)
                Circle().fill(Color(red: 1, green: 0.92, blue: 0.75).opacity(flicker)).frame(width: 11)
                    .position(x: lampX, y: lampY + 1)
                    .shadow(color: .orange.opacity(0.9), radius: 12)
            }
        }
        .ignoresSafeArea()
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 1.5...5)))
                for _ in 0..<Int.random(in: 1...3) {
                    flicker = Double.random(in: 0.25...0.6)
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 40...90)))
                    flicker = 1
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 40...80)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Dust and drizzle caught in the lamp's cone.
private struct Dust: View {
    let lampX: CGFloat, lampY: CGFloat, size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            Canvas { g, _ in
                let t = ctx.date.timeIntervalSinceReferenceDate
                var r = SplitMix(seed: 99)
                for _ in 0..<70 {
                    let u = Double(r.next() % 1000) / 1000, v = Double(r.next() % 1000) / 1000
                    let speed = 6 + Double(r.next() % 100) / 10
                    let depth = (v * size.height * 0.74 + t * speed).truncatingRemainder(dividingBy: size.height * 0.74)
                    let spread = depth / (size.height * 0.74)
                    let x = lampX + (u - 0.5) * size.width * 1.0 * spread + sin(t * 0.6 + u * 9) * 6
                    let y = lampY + depth
                    let a = (1 - spread) * 0.5 + 0.1
                    g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(Color(red: 1, green: 0.9, blue: 0.75).opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Fog: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ForEach(0..<3) { i in
                    Ellipse()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.5)
                        .blur(radius: 24)
                        .offset(x: CGFloat(sin(t * 0.08 + Double(i) * 2.1)) * geo.size.width * 0.3,
                                y: geo.size.height * (0.2 + Double(i) * 0.15))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Outcome

private struct OutcomeView: View {
    let outcome: Outcome
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                Rectangle().fill(outcome.good ? Noir.paper : Noir.neon).frame(width: 40, height: 3)
                Text(outcome.title).font(Noir.display(46)).foregroundStyle(Noir.paper)
                Text(outcome.text).font(Noir.type(17)).foregroundStyle(Noir.silver)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Carry on", action: onDone).buttonStyle(.noirPrimary)
            }
            .padding(24)
            FilmGrain()
        }
    }
}

// MARK: The end

private struct CaseClosed: View {
    let over: GameOver
    let s: GameState
    var onDone: () -> Void
    var onNewGame: () -> Void = {}
    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @State private var shareImage: Image?
    @State private var shown = 0
    @State private var cursor = true
    @State private var glitch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A good run: alive, not raided or busted, and up on the starting stake.
    private var good: Bool {
        !over.died && !["raid", "scorefail", "jail"].contains(over.ending ?? "") && over.worth > 2_500
    }
    private var tint: Color { good ? Noir.green : Noir.red }

    struct Line: Identifiable { let id: Int; let tag: String; let text: String; let colour: Color }

    private var lines: [Line] {
        var out: [Line] = []
        func add(_ tag: String, _ text: String, _ c: Color = Noir.paper) { out.append(Line(id: out.count, tag: tag, text: text, colour: c)) }
        let st = s.stats
        let mode = Engine.mode(s)
        add(">", "noirnet archive :: case file \(String(format: "%05d", s.seed % 99_999))", Noir.dim)
        add(">", "subject: \(s.playerName.isEmpty ? "ANONYMOUS" : s.playerName.uppercased()) :: \(mode.title.lowercased()) :: \(Engine.perk(s)?.title.lowercased() ?? "no background")", Noir.dim)
        add("STATUS", over.died ? "DECEASED" : Engine.endingTitle(over.ending).uppercased(), tint)
        add("NET WORTH", Money.gbp(over.worth), over.worth >= 0 ? Noir.green : Noir.red)
        add("RANK", Catalog.ranks[over.rank].name.uppercased(), Noir.amber)
        add("CASH / BANK", "\(Money.gbp(s.cash)) / \(Money.gbp(s.bank))")
        let debt = Engine.debt(s)
        add("DEBT", debt > 0 ? Money.gbp(debt) : "none", debt > 0 ? Noir.red : Noir.green)
        add("HEALTH", "\(s.health)%", Noir.rag(s.health, highIsGood: true))
        add("RESPECT", "\(s.rep)/100", Noir.rag(s.rep, highIsGood: true))
        add("HEAT", "\(s.heat)%", Noir.rag(s.heat, highIsGood: false))
        add("DAYS", "\(min(s.day, s.maxDay)) of \(s.maxDay)")
        if let best = st.bestDeal, best > 0 { add("BEST DEAL", "+\(Money.gbp(best)) · \(st.bestDealText ?? "")", Noir.green) }
        if let worst = st.worstLoss, worst < 0 { add("WORST HIT", "−\(Money.gbp(-worst)) · \(st.worstLossText ?? "")", Noir.red) }
        if let lost = st.totalLost, lost > 0 { add("TOTAL LOST", Money.gbp(lost), Noir.red) }
        add("BIGGEST SALE", Money.gbp(st.biggestSale))
        add("PEAK WORTH", Money.gbp(st.bestWorth))
        let goals = (st.earned ?? []).compactMap { id in Achievement.all.first { $0.id == id }?.title }
        add("GOALS", goals.isEmpty ? "none this time" : goals.map { "✓ \($0)" }.joined(separator: "  "), goals.isEmpty ? Noir.dim : Noir.amber)
        add("TRADE", "\(st.unitsBought) bought · \(st.unitsSold) sold · \(st.contractsDone ?? 0) contracts · \(st.dealsDone) phone deals")
        add("TRAVEL", "\(st.trips) trips · \((s.visited ?? []).count) \((s.visited ?? []).count == 1 ? "city" : "cities") · \(st.shipmentsSent) shipped, \(st.shipmentsLost) lost")
        add("STREET", "\(st.fightsWon) fights won · \(st.fightsLost) lost · \(st.escapes) escapes · robbed \(st.mugged)×")
        add("LAW", "\(st.arrests) arrests · \(st.bribesPaid) bribes · \(st.jailDays) nights inside")
        add("EMPIRE", "\((s.businesses ?? []).count) fronts · \((s.crew ?? []).count) crew · \(st.tipsBought) tips bought")
        add("VERDICT", over.epitaph, tint)
        add(">", good ? "file closed. well played." : "file terminated.", Noir.dim)
        return out
    }

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.14), .clear], center: .top, startRadius: 10, endRadius: 520).ignoresSafeArea()
            Scanlines().ignoresSafeArea()
            if good { Confetti().ignoresSafeArea() }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(tint).frame(width: 8, height: 8).glow(tint, radius: 6)
                    Text("NOIRNET").font(Noir.display(22)).foregroundStyle(tint)
                    Text("// CASE FILE").font(Noir.label(10)).tracking(1.2).foregroundStyle(tint.opacity(0.7))
                    Spacer()
                }
                Text(good ? (over.ending == "spain" ? "RETIRED." : "CASE CLOSED.") : (over.died ? "FLATLINED." : "BUSTED."))
                    .font(Noir.title(46))
                    .foregroundStyle(tint)
                    .shadow(color: tint.opacity(0.6), radius: 14)
                    .offset(x: glitch ? 4 : 0)
                    .padding(.top, 10)
                Text(Money.gbp(over.worth))
                    .font(Noir.mono(30))
                    .foregroundStyle(over.worth >= 0 ? Noir.paper : Noir.red)
                if let worth = s.stats.worthByDay, worth.count > 2 {
                    Sparkline(values: worth, colour: tint).frame(height: 36).padding(.vertical, 8)
                }
                Rectangle().fill(tint.opacity(0.35)).frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(lines.prefix(shown)) { l in
                                (Text(l.tag == ">" ? "> " : "[\(l.tag)] ").foregroundStyle(l.tag == ">" ? Noir.dim : tint.opacity(0.85))
                                 + Text(l.text).foregroundStyle(l.colour))
                                    .font(Noir.ui(13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(l.id)
                            }
                            Text(cursor ? "█" : " ").font(Noir.ui(13)).foregroundStyle(tint).id(-1)
                        }
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: shown) { withAnimation { proxy.scrollTo(-1, anchor: .bottom) } }
                }

                if !unlock.full && shown >= lines.count {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WANT A BIGGER PATCH?").font(Noir.label(11)).tracking(1.2).foregroundStyle(Noir.amber)
                            Text("11 more cities, Long Game and Sprint, backgrounds and palettes.")
                                .font(Noir.ui(11)).foregroundStyle(Noir.silver)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Button(unlock.busy ? "…" : (unlock.product?.displayPrice ?? "Unlock")) { Task { await unlock.purchase() } }
                            .buttonStyle(.noirAmber)
                            .frame(width: 96)
                            .disabled(unlock.busy)
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
                HStack(spacing: 10) {
                    Button(good ? "New game" : "Try again") { Audio.shared.play(.click, volume: 0.6); onNewGame() }
                        .buttonStyle(good ? NoirButtonStyle(kind: .primary) : NoirButtonStyle(kind: .danger))
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("Noir Market case file", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(AmberTile(size: 50))
                        .accessibilityLabel("Share your case file")
                    }
                }
                .opacity(shown >= lines.count ? 1 : 0.35)
                Button("Back to the title") { Audio.shared.play(.click, volume: 0.5); onDone() }
                    .buttonStyle(.noirQuiet)
                    .padding(.top, 2)
                    .opacity(shown >= lines.count ? 1 : 0.35)
            }
            .padding(20)
        }
        .contentShape(Rectangle())
        .onTapGesture { shown = lines.count }
        .onAppear {
            let renderer = ImageRenderer(content: ShareCard(over: over, s: s, good: good))
            renderer.scale = 3
            if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
        }
        .task {
            Audio.shared.play(good ? .win : .lose, volume: 0.6)
            Audio.shared.buzz(good ? .success : .danger)
            if reduceMotion { shown = lines.count; return }
            while shown < lines.count {
                try? await Task.sleep(for: .milliseconds(110))
                shown += 1
                Audio.shared.play(.key, volume: 0.15)
                Audio.shared.typeTick()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                cursor.toggle()
                if !good && !reduceMotion && Int.random(in: 0..<4) == 0 {
                    glitch = true
                    try? await Task.sleep(for: .milliseconds(60))
                    glitch = false
                }
            }
        }
    }
}

/// Green powder bursting up and drifting down: the celebration.
private struct Confetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                var r = SplitMix(seed: 31)
                for i in 0..<160 {
                    let vx = (Double(r.next() % 1000) / 1000 - 0.5) * 420
                    let vy = -(260 + Double(r.next() % 1000) / 1000 * 420)
                    let delay = Double(i % 3) * 0.35
                    let tt = max(0, t - delay)
                    guard tt > 0, tt < 4.5 else { continue }
                    let x = size.width / 2 + vx * tt
                    let y = size.height * 0.32 + vy * tt + 420 * tt * tt
                    let a = max(0, 1 - tt / 4.5)
                    let sz = 2 + Double(r.next() % 4)
                    let c: Color = i % 5 == 0 ? Noir.amber : i % 7 == 0 ? .white : Noir.green
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: sz, height: sz)), with: .color(c.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The last night: pick how it ends.
private struct EndingChoice: View {
    let s: GameState
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            RadialGradient(colors: [Noir.amber.opacity(0.08), .clear], center: .top, startRadius: 20, endRadius: 500).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The last night").noirLabel(12, color: Noir.amber).padding(.top, 40)
                    Text("How does it end?").font(Noir.display(40)).foregroundStyle(Noir.paper)
                    Text("You’re worth \(Money.gbp(Engine.netWorth(s))) tonight.\(s.heat >= 70 ? " And the heat is on: with this much attention, the police might get there first." : "")")
                        .font(Noir.ui(14)).foregroundStyle(s.heat >= 70 ? Noir.red : Noir.silver)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Engine.endingOptions(s)) { o in
                        Button {
                            Audio.shared.play(.click, volume: 0.6)
                            store.act { Engine.chooseEnding(&$0, o.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                GlowIcon(symbol: o.id == .spain ? "sun.horizon.fill" : o.id == .score ? "suitcase.fill" : "figure.walk",
                                         color: o.id == .score ? Noir.red : o.id == .spain ? Noir.green : Noir.amber, size: 40, lit: o.available)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(o.title.uppercased()).font(Noir.label(13)).tracking(1.2).foregroundStyle(o.available ? Noir.paper : Noir.dim)
                                    Text(o.detail).font(Noir.ui(12)).foregroundStyle(Noir.silver).fixedSize(horizontal: false, vertical: true)
                                    if let r = o.reason { Text(r).font(Noir.ui(11)).foregroundStyle(Noir.red) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(o.available ? 0.06 : 0.02)))
                            .overlay { if o.available { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.7)) } }
                        }
                        .buttonStyle(.plain)
                        .disabled(!o.available)
                    }
                    Button("Not yet") {
                        store.act { $0.pendingEnding = nil }
                    }
                    .buttonStyle(.noirQuiet)
                    .padding(.bottom, 30)
                }
                .padding(24)
            }
            FilmGrain()
        }
    }
}


/// The shareable case file: a square card with the result, in the game's NOIRNET style.
private struct ShareCard: View {
    let over: GameOver
    let s: GameState
    let good: Bool

    var body: some View {
        let tint = good ? Color(hex: 0x29FF85) : Color(hex: 0xFF4D4D)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text("NOIRNET").font(Noir.display(18)).foregroundStyle(tint)
                Text("// CASE FILE").font(Noir.label(9)).tracking(1.2).foregroundStyle(tint.opacity(0.7))
                Spacer()
                Text("DAY \(min(s.day, s.maxDay))/\(s.maxDay)").font(Noir.label(9)).tracking(1.2).foregroundStyle(Color.white.opacity(0.5))
            }
            Text(good ? (over.ending == "spain" ? "RETIRED." : "CASE CLOSED.") : (over.died ? "FLATLINED." : "BUSTED."))
                .font(Noir.title(40)).foregroundStyle(tint)
            Text(Money.gbp(over.worth)).font(Noir.mono(30)).foregroundStyle(Color.white)
            if let worth = s.stats.worthByDay, worth.count > 2 {
                Sparkline(values: worth, colour: tint).frame(height: 40)
            }
            VStack(alignment: .leading, spacing: 6) {
                row("RANK", Catalog.ranks[over.rank].name.uppercased(), Color(hex: 0xF5BD4D))
                row("MODE", Engine.mode(s).title.uppercased(), Color.white)
                row("CITIES", "\((s.visited ?? []).count)", Color.white)
            }
            Text(over.epitaph).font(Noir.ui(12)).foregroundStyle(tint.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: -4) {
                    Text("NOIR").font(Noir.title(26)).foregroundStyle(Color.white)
                    Text("MARKET").font(Noir.title(20)).foregroundStyle(Color(hex: 0xFF4D4D))
                }
                Spacer()
                Text("fiction · 18+").font(Noir.ui(9)).foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .padding(28)
        .frame(width: 400, height: 500)
        .background(Color(hex: 0x090909))
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(tint.opacity(0.5), lineWidth: 2))
    }

    private func row(_ tag: String, _ value: String, _ colour: Color) -> some View {
        (Text("[\(tag)] ").foregroundStyle(Color.white.opacity(0.5)) + Text(value).foregroundStyle(colour))
            .font(Noir.ui(13))
    }
}
