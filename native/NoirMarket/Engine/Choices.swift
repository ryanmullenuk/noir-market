import Foundation

/// Overnight choices, the rival dealer, Ironman rules and the "why did that happen?" explanations.
extension Engine {
    // MARK: The rival dealer

    static let rivalNames = ["Vinnie “The Vicar” Doyle", "Mags Okafor", "The Cartwright Brothers", "Dez Malone",
                             "Sully Byrne", "Nadia “Ice” Kovač", "Big Tel", "Rosie Quill"]

    static func rivalHolds(_ s: GameState, _ city: Int) -> Bool {
        guard let r = s.rival, !r.beaten else { return false }
        return r.cities.contains(city)
    }

    /// Picks the game's rival and their starting city: somewhere the player can reach, but not where they start.
    static func spawnRival(_ s: inout GameState) {
        let options = Catalog.cities.indices.filter { $0 != s.city && accessible(s, $0) }
        guard let home = options.isEmpty ? nil : options[Int(s.rng.next() % UInt64(options.count))] else { return }
        s.rival = RivalDealer(name: rivalNames[Int(s.rng.next() % UInt64(rivalNames.count))], cities: [home], beaten: false)
    }

    /// Every few nights the rival moves into the nearest city they don't run yet. Returns the news line, if any.
    static func rivalExpands(_ s: inout GameState, force: Bool = false) -> String? {
        guard var r = s.rival, !r.beaten, !r.cities.isEmpty, force || s.day % 4 == 0 else { return nil }
        // Never every city you can reach: there's always somewhere they don't run.
        let reachable = Catalog.cities.indices.filter { accessible(s, $0) }.count
        let cap = min(mode(s) == .long ? 9 : mode(s) == .sprint ? 3 : 6, max(1, reachable / 2))
        guard r.cities.count < cap else { return nil }
        let candidates = Catalog.cities.indices.filter { c in !r.cities.contains(c) && accessible(s, c) }
        guard let next = candidates.min(by: { a, b in
            r.cities.map { Catalog.cities[$0].distanceKm(to: Catalog.cities[a]) }.min()! <
            r.cities.map { Catalog.cities[$0].distanceKm(to: Catalog.cities[b]) }.min()!
        }) else { return nil }
        r.cities.append(next)
        s.rival = r
        return "\(r.name.uppercased()) MOVES INTO \(Catalog.cities[next].name.uppercased()). Their people undercut everyone on the street."
    }

    /// What it costs to buy the rival out of one city.
    static func rivalBuyoutCost(_ s: GameState) -> Int { 12_000 + 8_000 * (s.rival?.cities.count ?? 1) }

    static func buyOutRival(_ s: inout GameState) throws {
        try idle(s)
        guard rivalHolds(s, s.city), var r = s.rival else { throw Failure.invalid("No rival runs this city.") }
        let cost = rivalBuyoutCost(s)
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        record(&s, -cost, "Bought \(r.name) out of \(Catalog.cities[s.city].name)")
        r.cities.removeAll { $0 == s.city }
        s.rival = r
        rivalLost(&s, how: "A brown envelope later, \(r.name)’s people leave \(Catalog.cities[s.city].name) to you.")
    }

    /// Takes the fight to the rival in this city: their crew turns up.
    static func moveOnRival(_ s: inout GameState) throws {
        try idle(s)
        guard rivalHolds(s, s.city), let r = s.rival else { throw Failure.invalid("No rival runs this city.") }
        var t = trouble(&s, attacker: 3)
        t.crew = r.name
        t.why = "You went looking for \(r.name)’s crew in \(Catalog.cities[s.city].name). You found them."
        s.encounters.append(.trouble(t))
    }

    /// Called when the rival loses a city (bought out or beaten).
    static func rivalLost(_ s: inout GameState, how: String) {
        guard var r = s.rival else { return }
        changeRespect(&s, 5)
        if r.cities.isEmpty {
            r.beaten = true
            s.rival = r
            changeRespect(&s, 8)
            s.notice = how + " That was their last city. \(r.name) is finished."
        } else {
            s.notice = how + " They still run \(r.cities.count) \(r.cities.count == 1 ? "city" : "cities")."
        }
    }

    // MARK: Ironman

    static func heatMultiplier(_ s: GameState) -> Int { mode(s) == .ironman ? 2 : 1 }

    // MARK: Overnight choices

    /// Maybe puts a decision in front of the player tonight.
    static func maybeDilemma(_ s: inout GameState) {
        guard mode(s) != .tutorial, s.day >= 3, s.day < s.maxDay, s.dilemma == nil, s.encounters.isEmpty, s.raid == nil,
              s.over == nil, s.rng.chance(0.16) else { return }
        var kinds = ["journalist", "copper", "dock", "cousin"]
        if !(s.crew ?? []).isEmpty { kinds.append("raise") }
        if let r = s.rival, !r.beaten, r.cities.count >= 2, !r.cities.contains(s.city) { kinds.append("rivaloffer") }
        let kind = kinds[Int(s.rng.next() % UInt64(kinds.count))]
        let city = Catalog.cities[s.city].name
        switch kind {
        case "journalist":
            let cost = (2_000 + s.heat * 60) / 100 * 100
            s.dilemma = Dilemma(kind: kind, title: "A journalist is asking questions",
                                text: "A reporter from the \(city) Echo has your description and a notebook full of names. She’s writing it up for Sunday.",
                                options: ["Pay her to drop it · \(Money.gbp(cost))", "Ignore her"],
                                details: ["Heat −15", "Could go either way"], symbol: "newspaper.fill", values: [cost])
        case "copper":
            let cost = (4_000 + s.day * 250) / 100 * 100
            s.dilemma = Dilemma(kind: kind, title: "A bent copper makes an offer",
                                text: "A detective sergeant slides into your booth. For \(Money.gbp(cost)) he’ll make sure nobody in uniform bothers you for three nights.",
                                options: ["Pay for protection · \(Money.gbp(cost))", "Turn him down"],
                                details: ["No police stops for 3 nights", "He might take it personally"], symbol: "shield.lefthalf.filled", values: [cost])
        case "dock":
            let cities = Catalog.cities.indices.filter { accessible(s, $0) }
            let c = cities[Int(s.rng.next() % UInt64(cities.count))]
            let g = Int(s.rng.next() % UInt64(Catalog.goods.count))
            s.dilemma = Dilemma(kind: kind, title: "A docker has a tip",
                                text: "A docker leans in: a container lands somewhere tomorrow night, and whoever’s there first buys it for next to nothing. Where, and what’s in it, costs £1,500.",
                                options: ["Pay for the tip · £1,500", "Not interested"],
                                details: ["Find out where and what", "Keep your money. The container goes to someone else"],
                                symbol: "shippingbox.fill", values: [1_500, c, g])
        case "cousin":
            let reward = (2_500 + s.day * 150) / 100 * 100
            s.dilemma = Dilemma(kind: kind, title: "Your cousin needs a favour",
                                text: "Your cousin needs somewhere to keep “a few boxes” for a week. He’ll pay \(Money.gbp(reward)), no questions. The boxes are heavy and they ring.",
                                options: ["Take the boxes · +\(Money.gbp(reward))", "Say no"],
                                details: ["Heat +12", "Family will talk"], symbol: "figure.2", values: [reward])
        case "raise":
            let role = (s.crew ?? [])[Int(s.rng.next() % UInt64((s.crew ?? []).count))]
            let cost = Catalog.crewRoles[role].wage * 6
            s.dilemma = Dilemma(kind: kind, title: "Your \(Catalog.crewRoles[role].name.lowercased()) wants more",
                                text: "Your \(Catalog.crewRoles[role].name.lowercased()) says the risk has gone up and so has the price. A bonus of \(Money.gbp(cost)), or they walk.",
                                options: ["Pay the bonus · \(Money.gbp(cost))", "Let them walk"],
                                details: ["Keep your crew loyal", "They know where you sleep"], symbol: Catalog.crewRoles[role].symbol, values: [cost, role])
        default:
            let r = s.rival!
            let offer = 6_000 * r.cities.count
            s.dilemma = Dilemma(kind: "rivaloffer", title: "\(r.name) sends a message",
                                text: "A car pulls up. \(r.name) is offering you \(Money.gbp(offer)) to stay out of their cities for good. The driver doesn’t switch the engine off.",
                                options: ["Take the money · +\(Money.gbp(offer))", "Tell them where to go"],
                                details: ["Respect −8", "Respect +4, and they’ll expand"], symbol: "person.fill.questionmark", values: [offer])
        }
    }

    /// Settles tonight's decision. Returns a headline and text for the result card, and whether it went well.
    @discardableResult
    static func resolveDilemma(_ s: inout GameState, option: Int) throws -> (title: String, text: String, good: Bool, amount: Int?) {
        guard let d = s.dilemma else { throw Failure.invalid("Nothing to decide.") }
        let take = option == 0
        if take, ["journalist", "copper", "dock", "raise"].contains(d.kind), s.cash < d.values[0] { throw Failure.notEnoughCash }
        s.dilemma = nil
        switch d.kind {
        case "journalist":
            if take {
                s.cash -= d.values[0]; s.heat = max(0, s.heat - 15)
                return ("Story spiked", "She takes the envelope and the story goes in a drawer. Heat −15.", true, -d.values[0])
            }
            if s.rng.chance(0.5) {
                s.heat = min(100, s.heat + 15)
                return ("Front page", "Sunday’s Echo runs it across two pages. Every copper in \(Catalog.cities[s.city].name) reads it. Heat +15.", false, nil)
            }
            changeRespect(&s, 5)
            return ("Legend in print", "The story makes you sound untouchable. The street reads it too. Respect +5.", true, nil)
        case "copper":
            if take {
                s.cash -= d.values[0]; s.protectedUntil = s.day + 3
                return ("Protected", "He pockets it and nods. No uniform will stop you for the next three nights.", true, -d.values[0])
            }
            if s.rng.chance(0.25) {
                s.heat = min(100, s.heat + 10)
                return ("Bad move", "He takes it personally. Your name goes on a whiteboard somewhere. Heat +10.", false, nil)
            }
            return ("Walked away", "He shrugs and finishes your drink.", true, nil)
        case "dock":
            guard take else { return ("Passed", "You keep your money. Someone else will be waiting at the docks tomorrow.", true, nil) }
            s.cash -= d.values[0]
            // Dockers lie: about one tip in four is nonsense. Tomorrow's NOIRNET tells you which.
            s.dockDeal = [d.values[1], d.values[2], s.day + 1, s.rng.chance(0.75) ? 1 : 0]
            return ("Tip bought", "\(Catalog.goods[d.values[2]].name), landing in \(Catalog.cities[d.values[1]].name). Be there tomorrow and it’ll be going for next to nothing.", true, -d.values[0])
        case "cousin":
            guard take else { return ("Family drama", "Your cousin calls you a coward and hangs up. Probably for the best.", true, nil) }
            s.cash += d.values[0]; s.heat = min(100, s.heat + 12)
            return ("Boxes stored", "\(Money.gbp(d.values[0])) in your pocket and something ticking in your spare room. Heat +12.", true, d.values[0])
        case "raise":
            let role = d.values[1]
            if take {
                s.cash -= d.values[0]
                return ("Loyalty bought", "Your \(Catalog.crewRoles[role].name.lowercased()) is happy. For now.", true, -d.values[0])
            }
            s.crew = (s.crew ?? []).filter { $0 != role }
            if s.rng.chance(0.4) {
                s.heat = min(100, s.heat + 20)
                return ("Bridges burned", "They walk, and they talk on the way out. Heat +20.", false, nil)
            }
            return ("Walked", "They clear out their locker and go. No hard feelings, apparently.", true, nil)
        default:
            if take {
                s.cash += d.values[0]; changeRespect(&s, -8)
                s.rivalPaid = d.values[0]
                let cities = (s.rival?.cities ?? []).map { Catalog.cities[$0].name }.joined(separator: ", ")
                return ("Paid off", "You take the money. Now stay out of \(cities). Word gets round that you can be bought. Respect −8.", false, d.values[0])
            }
            changeRespect(&s, 4)
            let line = rivalExpands(&s, force: true)
            return ("Message sent", "You send the driver back with a message they won’t repeat. Respect +4." + (line.map { " " + $0.capitalized } ?? ""), true, nil)
        }
    }

    /// The tipped-off container lands (or doesn't). Returns the verdict for the morning's NOIRNET.
    static func applyDockDeal(_ s: inout GameState) -> String? {
        guard let d = s.dockDeal, d.count >= 3, s.day >= d[2] else { return nil }
        s.dockDeal = nil
        let city = Catalog.cities[d[0]].name, good = Catalog.goods[d[1]].name
        if d.count < 4 || d[3] == 1 {
            s.markets[d[0]].price[d[1]] = max(1, s.markets[d[0]].price[d[1]] * 45 / 100)
            s.markets[d[0]].supply[d[1]] += 200
            return "TIP PAID OFF: the docker’s container landed in \(city). \(good) now \(Money.gbp(s.markets[d[0]].price[d[1]])). Get there before it’s gone."
        }
        return "TIP WAS WRONG: no container in \(city), no \(good), no docker. Your £1,500 has gone the same way."
    }

    // MARK: Why did that happen?

    static func policeWhy(_ s: GameState, chance: Double, flight: Bool) -> String {
        let units = carried(s)
        var causes: [String] = []
        if s.heat >= 25 { causes.append("heat at \(s.heat)%") }
        if units > 0 { causes.append("\(units) units on you") }
        if hasWeapons(s) { causes.append("a weapon on you") }
        if flight { causes.append("an airport full of customs") }
        if eventHere(s, "match") { causes.append("a match-day crackdown") }
        if mode(s) == .ironman { causes.append("Ironman heat") }
        let times = max(1, Int((chance / 0.015).rounded()))
        var helps: [String] = []
        if s.weather == "rain" { helps.append("rain") }
        if hasCrew(s, 1) { helps.append("your lookout") }
        if perk(s) == .copper { helps.append("your old badge") }
        let base = causes.isEmpty ? "Just bad luck tonight." : "\(causes.joined(separator: ", ").capitalizedFirst) made a stop about \(times)× likelier than walking around clean."
        return helps.isEmpty ? base : base + " " + helps.joined(separator: " and ").capitalizedFirst + " kept the odds down."
    }

    static func troubleWhy(_ s: GameState) -> String {
        var causes: [String] = []
        let exposed = s.cash + carriedValue(s)
        if exposed > 100_000 { causes.append("walking round with \(Money.short(exposed)) in cash and stock") }
        else if s.cash > 20_000 { causes.append("\(Money.short(s.cash)) in your pocket") }
        if s.rep < 30 { causes.append("a reputation as an easy mark (respect \(s.rep))") }
        if s.weather == "fog" { causes.append("fog") }
        if causes.isEmpty { return "Wrong street, wrong night. Keeping cash in the bank and respect high keeps them away." }
        return causes.joined(separator: ", ").capitalizedFirst + " drew them out. Bank your cash: they size you up by what you carry."
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Engine {
    /// For a city the player hasn't unlocked: the best thing it pays more for than here, today.
    static func lockedTeaser(_ s: GameState, _ city: Int, long: Bool = false) -> String? {
        let here = s.markets[s.city], there = s.markets[city]
        let best = Catalog.goods.indices
            .filter { here.price[$0] > 0 && there.price[$0] > 0 && there.supply[$0] > 0 }
            .max { Double(there.price[$0]) / Double(here.price[$0]) < Double(there.price[$1]) / Double(here.price[$1]) }
        guard let g = best else { return nil }
        let pct = Int(((Double(there.price[g]) / Double(here.price[g]) - 1) * 100).rounded())
        guard pct >= 10 else { return nil }
        let name = Catalog.goods[g].name
        return long ? "\(Catalog.cities[city].name) pays \(pct)% more for \(name) than \(Catalog.cities[s.city].name) today. Full Game opens it."
                    : "Pays +\(pct)% for \(name) today"
    }
}


extension Engine {
    // MARK: Breaking the rival's deal

    /// True when you took the rival's money and this city is one of theirs.
    static func offLimits(_ s: GameState, _ city: Int) -> Bool { s.rivalPaid != nil && rivalHolds(s, city) }

    /// What it costs to buy your way out: the pay-off back, plus half again.
    static func paybackAmount(_ s: GameState) -> Int { ((s.rivalPaid ?? 0) * 3 / 2) / 100 * 100 }

    /// Spent a night in a city you were paid to stay out of: the rival's enforcers come to collect.
    static func rivalCollects(_ s: inout GameState) -> Bool {
        guard offLimits(s, s.city), let r = s.rival else { return false }
        var t = trouble(&s, attacker: 4)
        t.crew = r.name
        t.payback = paybackAmount(s)
        t.handOver = paybackAmount(s)
        t.runChance = max(0.1, t.runChance - 0.15)
        t.fightChance *= 0.75
        t.why = "You took \(r.name)’s money to stay out of their cities, then spent a night in \(Catalog.cities[s.city].name)."
        s.encounters.append(.trouble(t))
        return true
    }
}
