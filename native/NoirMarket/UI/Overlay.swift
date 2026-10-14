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

// MARK: The morning paper

private struct Newspaper: View {
    let report: DayReport
    let s: GameState
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Noir.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("The Evening Ledger")
                            .font(.custom("Didot", size: 34).weight(.bold))
                            .italic()
                        Rectangle().frame(height: 2)
                        HStack {
                            Text("Day \(report.day) of \(s.maxDay)")
                            Spacer()
                            Text(Catalog.cities[report.city].name + " edition")
                            Spacer()
                            Text("Price: 1p")
                        }
                        .font(.system(size: 10, weight: .semibold)).tracking(1).textCase(.uppercase)
                        Rectangle().frame(height: 1)
                    }

                    Text(report.story)
                        .font(.custom("Didot", size: 25).weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 18)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Our reporters stand by roughly half of this.")
                        .font(.system(size: 10)).italic()
                        .padding(.bottom, 14)

                    Rectangle().frame(height: 1)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(s.ticker.enumerated()), id: \.offset) { _, line in
                            let parts = line.split(separator: ".", maxSplits: 1).map(String.init)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(parts.first ?? line).font(.system(size: 12, weight: .heavy)).tracking(0.5)
                                if parts.count > 1 {
                                    Text(parts[1].trimmingCharacters(in: .whitespaces)).font(Noir.type(13))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 14)

                    Rectangle().frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your night").font(.system(size: 11, weight: .heavy)).tracking(2).textCase(.uppercase)
                        ForEach(Array(report.lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(Noir.type(14)).fixedSize(horizontal: false, vertical: true)
                        }
                        if !s.encounters.isEmpty {
                            Text("And then, on the way home…").font(Noir.type(14)).italic().foregroundStyle(Noir.blood)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                }
                .foregroundStyle(Noir.ink)
                .padding(20)
                .background(Noir.paper)
                .overlay(Rectangle().fill(.black.opacity(0.05)).blendMode(.multiply))
                .rotationEffect(.degrees(-0.6))
                .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                .padding(16)
                .padding(.top, 12)

                Button(s.encounters.isEmpty ? "Turn the page" : "Uh oh") {
                    Audio.shared.buzz(s.encounters.isEmpty ? .tap : .warning)
                    onDone()
                }
                .buttonStyle(s.encounters.isEmpty ? NoirButtonStyle(kind: .primary) : NoirButtonStyle(kind: .danger))
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
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
                    Meter(label: "Health", value: s.health, colour: s.health <= 30 ? Noir.neon : Noir.paper)
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
                                    Text("\(Int((odds * 100).rounded()))%").font(Noir.mono(13))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(NoirButtonStyle(kind: o.primary ? .primary : o.danger ? .danger : .secondary))
                        .disabled(!o.enabled)
                        .opacity(o.enabled ? 1 : 0.35)
                        if let note = o.note {
                            Text(note).font(.system(size: 11)).foregroundStyle(Noir.dim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, -6)
                        }
                    }
                }
            }
            .padding(24)
            FilmGrain()
        }
        .onAppear { Audio.shared.buzz(.danger) }
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
        store.act { try Engine.resolve(&$0, c) }
        if let o = store.state?.outcome { Audio.shared.buzz(o.good ? .success : .danger) }
    }
}

private struct PoliceLights: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
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
