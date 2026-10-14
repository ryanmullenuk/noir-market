import SwiftUI

/// Full-screen beats between days: the morning paper, then any trouble, then the result.
struct Overlay: View {
    var onQuit: () -> Void
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
                } else if let over = s.over {
                    CaseClosed(over: over, s: s, onDone: onQuit)
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
            Color.black.ignoresSafeArea()
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
            if case .police = encounter { Audio.shared.play(.siren, volume: 0.35) } else { Audio.shared.play(.thud) }
        }
    }

    @ViewBuilder private var backdrop: some View {
        switch encounter {
        case .police: PoliceLights()
        default: StreetLamp()
        }
    }

    private var kicker: String {
        switch encounter {
        case .police(let p): p.airport ? "Arrivals hall" : "Blue lights"
        case .trouble(let t): t.round > 1 ? "Round \(t.round)" : "A dark street"
        case .collector: "A knock at the door"
        }
    }

    private var title: String {
        switch encounter {
        case .police(let p): p.airport ? "Customs" : "Police Stop"
        case .trouble: "Trouble"
        case .collector(let c): "\(lenderName(c))’s Lads"
        }
    }

    private var text: String {
        let units = Engine.carried(s)
        switch encounter {
        case .police(let p):
            let what = units > 0 ? "\(units) units in your bag" : "nothing in your pockets but nerves"
            return (p.airport ? "A customs officer with tired eyes points at your bag. " : "A patrol car pulls up and two officers get out slowly. ")
                + "You’ve got \(what)." + (Engine.hasWeapons(s) ? " And something heavier under your coat." : "")
        case .trouble(let t):
            let a = Catalog.attackers[t.attacker]
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
            if weapon != nil {
                list.append(Option(choice: .fight, label: "Pull the \(weapon!.name.lowercased())", odds: p.fightChance, note: "Huge heat if it works. Worse if it doesn’t.", danger: true))
            }
            return list
        case .trouble(let t):
            return [
                Option(choice: .run, label: "Run", odds: t.runChance, primary: true),
                Option(choice: .fight, label: weapon.map { "Fight with the \($0.name.lowercased())" } ?? "Fight with your fists", odds: t.fightChance,
                       note: "Lose and you’ll get hurt.", danger: true),
                Option(choice: .handOver, label: "Hand over \(Money.gbp(min(s.cash, t.handOver)))",
                       note: t.attacker >= 2 ? "They’ll take some stock too." : "Nobody gets hurt."),
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
        store.act { try Engine.resolve(&$0, c) }
        if let o = store.state?.outcome { Audio.shared.buzz(o.good ? .success : .danger) }
        if (store.state?.health ?? health) < health { Audio.shared.play(.thud, volume: 0.8) }
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

private struct StreetLamp: View {
    @State private var flicker = 1.0
    var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * 0.7, top = 120.0
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: x - 8, y: top))
                    p.addLine(to: CGPoint(x: x + 8, y: top))
                    p.addLine(to: CGPoint(x: geo.size.width * 1.2, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.15, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.6).opacity(0.22 * flicker), .clear], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: x, y: top - 4))
                    p.addLine(to: CGPoint(x: x, y: top - 30))
                    p.addLine(to: CGPoint(x: x + 60, y: top - 30))
                    p.addLine(to: CGPoint(x: x + 60, y: geo.size.height))
                }
                .stroke(Color(white: 0.16), lineWidth: 4)
                Capsule().fill(Color(white: 0.2)).frame(width: 26, height: 8).position(x: x, y: top - 4)
                Circle().fill(Color(red: 1, green: 0.9, blue: 0.7).opacity(flicker)).frame(width: 10).position(x: x, y: top)
                    .shadow(color: .orange.opacity(0.8), radius: 12)
            }
        }
        .ignoresSafeArea()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 1...4)))
                flicker = 0.4
                try? await Task.sleep(for: .milliseconds(70))
                flicker = 1
            }
        }
        .accessibilityHidden(true)
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
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            Rain(intensity: 60)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(over.died ? "Obituary" : "Case closed").noirLabel(12, color: Noir.neon)
                        .padding(.top, 40)
                    Text(over.died ? "Lights out." : "Thirty days.").font(Noir.display(50)).foregroundStyle(Noir.paper)
                    Text(over.epitaph).font(Noir.type(17)).foregroundStyle(Noir.silver)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Net worth").noirLabel()
                        Text(Money.gbp(over.worth)).font(Noir.display(44)).foregroundStyle(over.worth >= 0 ? Noir.paper : Noir.neon)
                        Text(Catalog.ranks[over.rank].name).font(Noir.typeBold(18)).foregroundStyle(Noir.brass)
                        if let place = store.records.firstIndex(where: { $0.seed == s.seed }) {
                            Text(place == 0 ? "A new personal record." : "Number \(place + 1) in your records.")
                                .font(Noir.type(13)).foregroundStyle(Noir.silver)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 18)

                    let st = s.stats
                    VStack(spacing: 8) {
                        row("Trips taken", "\(st.trips)")
                        row("Units bought / sold", "\(st.unitsBought) / \(st.unitsSold)")
                        row("Biggest sale", Money.gbp(st.biggestSale))
                        row("Brushes with the law", "\(st.arrests + st.bribesPaid + st.escapes)")
                        row("Nights in a cell", "\(st.jailDays)")
                        row("Fights won / lost", "\(st.fightsWon) / \(st.fightsLost)")
                        row("Times robbed", "\(st.mugged)")
                        row("Best net worth", Money.gbp(st.bestWorth))
                    }
                    .card()

                    Button("Back to the street", action: onDone).buttonStyle(.noirPrimary)
                        .padding(.bottom, 30)
                }
                .padding(24)
            }
            FilmGrain()
        }
        .onAppear { Audio.shared.buzz(over.died ? .danger : .success) }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(Noir.type(14)).foregroundStyle(Noir.silver)
            Spacer()
            Text(v).font(Noir.mono(14)).foregroundStyle(Noir.paper)
        }
    }
}
