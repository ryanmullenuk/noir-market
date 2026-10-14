import Foundation

enum Choice: String, Codable, Sendable, CaseIterable {
    case comply, bribe, run, fight, handOver, pay, beating
}

extension Engine {
    static func carriedValue(_ s: GameState) -> Int {
        Catalog.goods.indices.reduce(0) { $0 + s.carry[$1] * s.markets[s.city].price[$1] }
    }

    static func policeStop(_ s: inout GameState, airport: Bool) -> PoliceStop {
        let value = carriedValue(s)
        let units = carried(s)
        let weapon = bestWeapon(s)
        let copper = perk(s) == .copper
        var bribe = min(60_000, max(500, 600 + value * 15 / 100 + s.heat * 30 + (airport ? 1_500 : 0))) / 10 * 10
        if copper { bribe = bribe * 3 / 4 / 10 * 10 }
        let bribeChance = clamp(0.30 + Double(s.rep) / 250 - Double(s.heat) / 500 - (airport ? 0.10 : 0) + (copper ? 0.15 : 0), 0.12, 0.9)
        let runChance = clamp(0.45 + (weapon?.escape ?? 0) * 0.35 - (airport ? 0.2 : 0) - Double(units) / 600, 0.10, 0.85)
        let fightChance = min(0.8, (weapon.map { clamp(0.10 + $0.win * 0.55, 0.10, 0.70) } ?? 0.05) + (hasCrew(s, 2) ? 0.1 : 0))
        let jail = (hasWeapons(s) || units > 50) ? s.rng.int(1, 3) : 0
        let fine = (s.rng.int(300, 2_500) + value / 20) / 10 * 10
        return PoliceStop(airport: airport, bribe: bribe, bribeChance: bribeChance, runChance: runChance,
                          fightChance: fightChance, jail: jail, fine: fine)
    }

    static func trouble(_ s: inout GameState, attacker forced: Int? = nil) -> Trouble {
        let attacker = forced ?? s.rng.pick(weights: Catalog.attackers.map(\.weight))
        let a = Catalog.attackers[attacker]
        let weapon = bestWeapon(s)
        let muscle = hasCrew(s, 2)
        let run = min(0.95, 0.5 + (weapon?.escape ?? 0) + (muscle ? 0.1 : 0) - (attacker == 4 ? 0.15 : 0))
        var fight: Double = weapon.map { attacker == 0 ? 0.75 : min(0.96, 0.10 + $0.win) } ?? (attacker == 0 ? 0.45 : 0.25)
        if attacker == 4 { fight *= 0.8 }
        if muscle { fight = min(0.96, fight + 0.15) }
        return Trouble(attacker: attacker, round: 1, runChance: run, fightChance: fight,
                       handOver: a.take(from: s.cash, fraction: a.loot))
    }

    /// Resolves the encounter at the front of the queue.
    @discardableResult
    static func resolve(_ s: inout GameState, _ choice: Choice) throws -> Outcome {
        guard let encounter = s.encounters.first else { throw Failure.invalid("Nothing to resolve.") }
        var keep = false
        let outcome: Outcome
        switch encounter {
        case .police(let stop): (outcome, keep) = try police(&s, stop, choice)
        case .trouble(let t): (outcome, keep) = try trouble(&s, t, choice)
        case .collector(let c): outcome = try collector(&s, c, choice)
        }
        if !keep, !s.encounters.isEmpty { s.encounters.removeFirst() }
        s.outcome = outcome
        checkEnd(&s)
        return outcome
    }

    // MARK: Police

    private static func police(_ s: inout GameState, _ stop: PoliceStop, _ choice: Choice) throws -> (Outcome, Bool) {
        let fought = (stop.round ?? 1) > 1
        var stop = stop
        if fought, choice == .comply || choice == .handOver { stop.jail += 2 }
        if choice == .fight { return try policeFight(&s, stop) }
        return (try policeOther(&s, stop, choice, fought: fought), false)
    }

    private static func policeFight(_ s: inout GameState, _ stop: PoliceStop) throws -> (Outcome, Bool) {
        let weapon = bestWeapon(s)
        let kind = WeaponKind(weapon)
        consume(&s, weapon)
        if s.rng.chance(stop.fightChance) {
            s.heat = min(100, s.heat + 25 + (weapon?.heat ?? 0))
            s.rep = min(100, s.rep + 5)
            s.stats.fightsWon += 1
            return (Outcome(title: "Fought Off", text: "It’s ugly and it’s loud and you’re the one still standing. Every copper in the city will know your face by morning.", good: true), false)
        }
        s.stats.fightsLost += 1
        if (stop.round ?? 1) < 2 {
            // A miss, not a defeat: they fire back and you get one more decision.
            let hurt = s.rng.int(8, 18)
            s.health -= hurt
            s.heat = min(100, s.heat + 10)
            if s.health <= 0 { return (Outcome(title: "Lights Out", text: "The return fire finds you first.", good: false), false) }
            if case .police(var next) = s.encounters[0] {
                next.round = 2
                next.fightChance = max(0.05, next.fightChance * 0.85)
                next.runChance = max(0.1, next.runChance - 0.1)
                s.encounters[0] = .police(next)
            }
            return (Outcome(title: kind.missTitle, text: "\(kind.missLine) They return fire: \(hurt)% health gone. Go again, run for it, or give yourself up (and pay for the trouble).", good: false), true)
        }
        let hurt = s.rng.int(15, 30)
        s.health -= hurt
        var harder = stop
        harder.jail += 2
        return (nicked(&s, harder, intro: "Second time unlucky. You lose \(hurt)% health and any sympathy. "), false)
    }

    private static func policeOther(_ s: inout GameState, _ stop: PoliceStop, _ choice: Choice, fought: Bool) throws -> Outcome {
        s.stats.arrests += choice == .comply ? 1 : 0
        switch choice {
        case .comply:
            return nicked(&s, stop, intro: "")
        case .handOver:
            guard carried(s) > 0 else { throw Failure.invalid("You’ve nothing to offer.") }
            var lost = 0
            for g in s.carry.indices where s.carry[g] > 0 {
                let take = (s.carry[g] + 1) / 2
                s.carryCost[g] -= s.carryCost[g] * take / s.carry[g]
                s.carry[g] -= take
                lost += take
            }
            s.heat = max(0, s.heat - 2)
            return Outcome(title: "Evidence Mislaid", text: "\(lost) units go into the boot of the patrol car and never come out again. Nobody writes anything down.", good: false)
        case .bribe:
            guard s.cash >= stop.bribe else { throw Failure.notEnoughCash }
            if s.rng.chance(stop.bribeChance) {
                s.cash -= stop.bribe
                s.heat = max(0, s.heat - 5)
                s.rep = min(100, s.rep + 1)
                s.stats.bribesPaid += 1
                if stop.airport { award(&s, "customs_bribe") }
                return Outcome(title: "Understanding Reached", text: "The envelope disappears into a coat pocket. “Mind how you go.” \(Money.gbp(stop.bribe)) lighter, you mind how you go.", good: true)
            }
            s.heat = min(100, s.heat + 10)
            s.rep = max(0, s.rep - 3)
            return nicked(&s, stop, intro: "He looks at the envelope, then at you, then reaches for the cuffs. ")
        case .run:
            if s.rng.chance(stop.runChance) {
                s.heat = min(100, s.heat + 8)
                s.stats.escapes += 1
                return Outcome(title: "Gone", text: stop.airport ? "You slip through a staff door, down a service stair and out into the taxi rank." : "Over a wall, through a garden, past a very surprised man in a dressing gown. You’re clear.", good: true)
            }
            let hurt = s.rng.int(5, 15)
            s.health -= hurt
            return nicked(&s, stop, intro: "You make it about twenty yards. The tackle costs you \(hurt)% health. ")
        default:
            throw Failure.invalid("Not an option.")
        }
    }

    private static func nicked(_ s: inout GameState, _ stop: PoliceStop, intro: String) -> Outcome {
        let units = carried(s)
        let armed = hasWeapons(s)
        if units == 0 && !armed {
            s.heat = max(0, s.heat - 6)
            return Outcome(title: "Clean", text: intro + "They turn out your pockets and find a bus ticket and some fluff. “On your way.”", good: true)
        }
        s.carry = s.carry.map { _ in 0 }
        s.carryCost = s.carryCost.map { _ in 0 }
        s.weapons = s.weapons.map { _ in 0 }
        let fine = min(s.cash, stop.fine)
        s.cash -= fine
        s.rep = max(0, s.rep - 5)
        var text = intro + "Everything you were carrying goes into evidence bags"
        text += fine > 0 ? ", and the fine comes to \(Money.gbp(fine))." : "."
        if stop.jail > 0 {
            var lines: [String] = []
            for _ in 0..<stop.jail where s.day <= s.maxDay { tick(&s, lines: &lines) }
            s.stats.jailDays += stop.jail
            if s.stats.jailDays >= 3 { award(&s, "jailbird") }
            s.heat = max(0, s.heat - 10 * stop.jail)
            text += " You spend \(stop.jail) night\(stop.jail == 1 ? "" : "s") in a cell while the city moves on without you."
        }
        return Outcome(title: stop.jail > 0 ? "Banged Up" : "Nicked", text: text, good: false)
    }

    // MARK: Street trouble

    private static func trouble(_ s: inout GameState, _ t: Trouble, _ choice: Choice) throws -> (Outcome, Bool) {
        let a = Catalog.attackers[t.attacker]
        switch choice {
        case .handOver:
            let take = min(s.cash, t.handOver)
            s.cash -= take
            var text = "You hand over \(Money.gbp(take))."
            if t.attacker >= 2 {
                for g in s.carry.indices where s.carry[g] > 0 {
                    let lost = s.carry[g] / 4
                    s.carryCost[g] -= s.carryCost[g] * lost / max(1, s.carry[g])
                    s.carry[g] -= lost
                }
                text += " They help themselves to a quarter of your stock as well."
            }
            s.stats.mugged += 1
            if t.crew != nil {
                lowerTurf(&s, city: s.city, by: 45)
                return (Outcome(title: "Tax Paid", text: text + " The \(t.crew!) call it ‘rent’. They’ll leave you be, for now.", good: false), false)
            }
            return (Outcome(title: "Robbed", text: text + " Nobody gets hurt. This time.", good: false), false)
        case .run:
            if s.rng.chance(t.runChance) {
                s.heat = min(100, s.heat + s.rng.int(1, 4))
                s.stats.escapes += 1
                return (Outcome(title: "Legged It", text: "You know these streets better than \(a.name) does. They give up at the third alley.", good: true), false)
            }
            let hurt = s.rng.int(max(2, a.damage / 2), a.damage)
            let take = a.take(from: s.cash, fraction: s.rng.uniform(0.05, a.loot))
            s.health -= hurt
            s.cash -= take
            s.stats.mugged += 1
            return (Outcome(title: "Caught", text: "They catch you by the bins. \(hurt)% health and \(Money.gbp(take)) later, they’re gone.", good: false), false)
        case .fight:
            let weapon = bestWeapon(s)
            let kind = WeaponKind(weapon)
            consume(&s, weapon)
            if s.rng.chance(t.fightChance) {
                s.heat = min(100, s.heat + s.rng.int(3, 10) + (weapon?.heat ?? 0) / 2)
                let dropped = s.rng.int(100, 400) * (t.attacker + 1) * (t.attacker + 1)
                s.cash += dropped
                s.stats.fightsWon += 1
                if let crew = t.crew {
                    lowerTurf(&s, city: s.city, by: 100)
                    s.rep = min(100, s.rep + 6)
                    award(&s, "turf_war")
                    return (Outcome(title: "Turf Won", text: "The \(crew) scatter. Word spreads fast: these streets are yours now. Someone dropped \(Money.gbp(dropped)) on the way out.", good: true), false)
                }
                if t.attacker == 3 && weapon == nil { award(&s, "bare_knuckle") }
                return (Outcome(title: "Sent Packing", text: "\(a.name.prefix(1).uppercased() + a.name.dropFirst()) thought better of it. One of them dropped a wallet: \(Money.gbp(dropped)).", good: true), false)
            }
            // A miss: they hit back, then you decide again.
            let reduction = min(0.85, weapon?.escape ?? 0)
            let base = Double(a.damage) * (1 - reduction)
            let hurt = s.rng.int(max(2, Int(base / 2)), max(3, Int(base.rounded())))
            s.health -= hurt
            s.stats.fightsLost += 1
            if s.health <= 0 {
                return (Outcome(title: "Lights Out", text: "You took one swing too many.", good: false), false)
            }
            if t.round < a.rounds + 2 {
                if case .trouble(var next) = s.encounters[0] {
                    next.round += 1
                    next.handOver = a.take(from: s.cash, fraction: min(0.9, a.loot * 1.3))
                    s.encounters[0] = .trouble(next)
                }
                return (Outcome(title: kind.missTitle, text: "\(kind.missLine) They hit back: \(hurt)% health gone. Keep fighting, run, or give up — and giving up now will cost you more.", good: false), true)
            }
            let take = a.take(from: s.cash, fraction: s.rng.uniform(0.05, a.loot))
            s.cash -= take
            return (Outcome(title: "Broke Away", text: "You lose \(hurt)% health and \(Money.gbp(take)), but you get away.", good: false), false)
        default:
            throw Failure.invalid("Not an option.")
        }
    }

    // MARK: Debt collector

    private static func collector(_ s: inout GameState, _ c: Collector, _ choice: Choice) throws -> Outcome {
        guard let i = s.loans.firstIndex(where: { $0.id == c.loan }) else {
            return Outcome(title: "Square", text: "They check the book. You’re square. They seem almost disappointed.", good: true)
        }
        let name = Catalog.lenders[s.loans[i].lender].name
        let owed = payoff(s.loans[i], day: s.day)
        switch choice {
        case .pay:
            let amount = min(s.cash, owed)
            guard amount > 0 else { throw Failure.notEnoughCash }
            s.cash -= amount
            if amount >= owed {
                s.loans.remove(at: i)
                return Outcome(title: "Paid Up", text: "\(name)’s lads count it twice and leave without a word. That’s the best kind of goodbye.", good: true)
            }
            s.loans[i].principal = owed - amount
            s.loans[i].due = s.day + 2
            s.loans[i].startDay = s.day
            s.loans[i].rate = 0.15
            s.loans[i].term = 2
            return Outcome(title: "Part Payment", text: "They take \(Money.gbp(amount)) and give you two more days for the rest, plus 15% for their trouble.", good: false)
        case .beating:
            let hurt = s.rng.int(10, 25)
            s.health -= hurt
            s.loans[i].due = s.day + 2
            s.loans[i].startDay = s.day
            s.loans[i].rate = 0.10
            s.loans[i].term = 2
            return Outcome(title: "A Reminder", text: "\(name) sends his regards, mostly to your ribs. \(hurt)% health gone. Two days to find the money.", good: false)
        default:
            throw Failure.invalid("Not an option.")
        }
    }

    private static func consume(_ s: inout GameState, _ weapon: Weapon?) {
        if let w = weapon, w.singleUse { s.weapons[w.id] = max(0, s.weapons[w.id] - 1) }
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }
}

extension Encounter {
    /// A cautious default, used by the balance bot and debug tooling.
    func defaultChoice(_ s: GameState) -> Choice {
        switch self {
        case .police(let p):
            if s.cash >= p.bribe && p.bribeChance > 0.4 { return .bribe }
            return Engine.carriedValue(s) > 3_000 ? .handOver : .comply
        case .trouble(let t): return t.runChance >= 0.6 ? .run : .handOver
        case .collector: return s.cash > 0 ? .pay : .beating
        }
    }
}

/// What you're swinging, for sounds and miss text.
enum WeaponKind {
    case gun, blade, explosive, fists

    init(_ w: Weapon?) {
        guard let w else { self = .fists; return }
        switch w.name {
        case "Knife", "Baseball Bat", "Machete": self = .blade
        case "Molotov Cocktail", "Grenade", "Rocket Launcher": self = .explosive
        default: self = .gun
        }
    }

    var missTitle: String {
        switch self {
        case .gun: "Missed"
        case .blade: "Blocked"
        case .explosive: "Wide"
        case .fists: "Wild Swing"
        }
    }

    var missLine: String {
        switch self {
        case .gun: "You fire. The shot goes high and takes out a streetlight."
        case .blade: "You swing. They see it coming and step inside it."
        case .explosive: "It goes off, loud and wide. Mostly you hit a wheelie bin."
        case .fists: "You throw everything into one punch and hit fresh air."
        }
    }
}
