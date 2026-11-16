import Foundation

/// Turf, fronts and laundering, crew, contracts and endings.
extension Engine {
    // MARK: Turf

    static func turf(_ s: GameState, _ city: Int) -> Int { s.turf?[city] ?? 0 }

    static func raiseTurf(_ s: inout GameState, by amount: Int) {
        guard Catalog.rivals[s.city] != nil else { return }
        var t = s.turf ?? Array(repeating: 0, count: Catalog.cities.count)
        t[s.city] = min(100, t[s.city] + amount)
        s.turf = t
    }

    static func lowerTurf(_ s: inout GameState, city: Int, by amount: Int) {
        guard var t = s.turf else { return }
        t[city] = max(0, t[city] - amount)
        s.turf = t
    }

    /// The local crew comes calling once you've been selling too much on its streets.
    static func rivalVisit(_ s: inout GameState) -> Bool {
        guard let crew = Catalog.rivals[s.city], mode(s) != .tutorial else { return false }
        let attention = turf(s, s.city)
        guard attention >= 45, s.rng.chance(Double(attention - 35) / 90) else { return false }
        var t = trouble(&s, attacker: 4)
        t.crew = crew
        s.encounters.append(.trouble(t))
        return true
    }

    // MARK: Fronts and laundering

    static func dirty(_ s: GameState) -> Int { min(s.dirty ?? 0, max(0, s.cash + s.bank)) }

    static func launderCapacity(_ s: GameState) -> Int {
        (s.businesses ?? []).reduce(0) { $0 + Catalog.businesses[$1].launders }
    }

    static func addDirty(_ s: inout GameState, _ amount: Int) {
        s.dirty = (s.dirty ?? 0) + max(0, amount)
    }

    static func buyBusiness(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        guard !(s.businesses ?? []).contains(id) else { throw Failure.invalid("You already own one.") }
        let b = Catalog.businesses[id]
        guard s.cash >= b.price else { throw Failure.notEnoughCash }
        s.cash -= b.price
        // Buying a front with dirty money is the first thing it washes.
        s.dirty = max(0, dirty(s) - b.price)
        s.businesses = (s.businesses ?? []) + [id]
        award(&s, "front")
        s.notice = "You’re now the proud owner of a \(b.name.lowercased()). Smile for the local paper."
    }

    /// Nightly: fronts earn and wash cash; unwashed money over the limit draws heat.
    static func runFronts(_ s: inout GameState, lines: inout [String]) {
        var income = 0
        for id in s.businesses ?? [] { income += Catalog.businesses[id].income }
        if income > 0 { s.cash += income }
        var d = dirty(s)
        let washed = min(d, launderCapacity(s))
        d -= washed
        s.dirty = d
        if income > 0 || washed > 0 {
            lines.append("Your fronts took \(Money.gbp(income)) and washed \(Money.gbp(washed)) of dirty cash.")
        }
        if d > Catalog.dirtyLimit {
            let extra = min(12, 4 + (d - Catalog.dirtyLimit) / 75_000)
            s.heat = min(100, s.heat + extra)
            lines.append("\(Money.short(d)) in unexplained cash is drawing questions. Heat +\(extra). Buy a front to wash it.")
        }
    }

    // MARK: Crew

    static func hasCrew(_ s: GameState, _ role: Int) -> Bool { (s.crew ?? []).contains(role) }

    static func hire(_ s: inout GameState, _ role: Int) throws {
        try idle(s)
        guard !hasCrew(s, role) else { throw Failure.invalid("You’ve already got one.") }
        let r = Catalog.crewRoles[role]
        guard s.cash >= r.wage else { throw Failure.notEnoughCash }
        s.cash -= r.wage
        s.crew = (s.crew ?? []) + [role]
        var unpaid = s.crewUnpaid ?? Array(repeating: 0, count: Catalog.crewRoles.count)
        unpaid[role] = 0
        s.crewUnpaid = unpaid
        s.notice = "Your new \(r.name.lowercased()) takes the first day’s \(Money.gbp(r.wage)) up front. Fair enough."
    }

    static func fire(_ s: inout GameState, _ role: Int) {
        s.crew = (s.crew ?? []).filter { $0 != role }
        s.notice = "You let your \(Catalog.crewRoles[role].name.lowercased()) go. They take it well. Suspiciously well."
    }

    /// Nightly wages. Two unpaid nights and they walk, and sometimes they talk.
    static func payCrew(_ s: inout GameState, lines: inout [String]) {
        guard let crew = s.crew, !crew.isEmpty else { return }
        var unpaid = s.crewUnpaid ?? Array(repeating: 0, count: Catalog.crewRoles.count)
        for role in crew {
            let r = Catalog.crewRoles[role]
            if s.cash >= r.wage {
                s.cash -= r.wage
                unpaid[role] = 0
            } else if s.bank >= r.wage {
                s.bank -= r.wage
                unpaid[role] = 0
            } else {
                unpaid[role] += 1
                if unpaid[role] >= 2 {
                    s.crew = (s.crew ?? []).filter { $0 != role }
                    if s.rng.chance(0.5) {
                        s.heat = min(100, s.heat + 25)
                        lines.append("Your unpaid \(r.name.lowercased()) has turned informant. Every copper in town has your description. Heat +25.")
                    } else {
                        lines.append("Your \(r.name.lowercased()) walked out over unpaid wages. At least they didn’t talk. Yet.")
                    }
                } else {
                    lines.append("You couldn’t pay your \(r.name.lowercased()) tonight. They’re counting.")
                }
            }
        }
        s.crewUnpaid = unpaid
    }

    // MARK: Contracts

    static func makeOffers(_ s: inout GameState) {
        guard mode(s) != .tutorial, s.day < s.maxDay - 1 else { s.offers = []; return }
        let cities = accessibleCities(s)
        var offers: [Contract] = []
        // More respect, more people want to do business with you.
        let count = s.rep < 25 ? 1 : s.rep >= 70 ? 3 : 2
        for _ in 0..<count {
            let city = cities[s.rng.int(0, cities.count - 1)]
            let good = s.rng.int(0, Catalog.goods.count - 1)
            let qty = max(5, Int(Double(capacity(s)) * s.rng.uniform(0.25, 0.7)) / 5 * 5)
            let due = min(s.maxDay, s.day + s.rng.int(3, 7))
            let unit = Catalog.goods[good].mid * Catalog.cities[city].factor(for: good)
            let reward = Int(unit * Double(qty) * s.rng.uniform(1.5, 2.1) * (1 + respect(s) * 0.15)) / 100 * 100
            offers.append(Contract(id: s.nextID, good: good, qty: qty, city: city, due: due, reward: reward))
            s.nextID += 1
        }
        s.offers = offers
    }

    static func acceptContract(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        guard let c = (s.offers ?? []).first(where: { $0.id == id }) else { throw Failure.invalid("That job’s gone.") }
        guard (s.contracts ?? []).count < 2 else { throw Failure.invalid("Two jobs at once is plenty.") }
        s.offers = (s.offers ?? []).filter { $0.id != id }
        s.contracts = (s.contracts ?? []) + [c]
        s.notice = "Job taken: \(c.qty) \(Catalog.goods[c.good].name) to \(Catalog.cities[c.city].name) by day \(c.due)."
    }

    static func canDeliver(_ s: GameState, _ c: Contract) -> Bool { c.city == s.city && s.carry[c.good] >= c.qty }

    static func deliver(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        guard let c = (s.contracts ?? []).first(where: { $0.id == id }) else { throw Failure.invalid("No such job.") }
        guard canDeliver(s, c) else { throw Failure.invalid("You need \(c.qty) \(Catalog.goods[c.good].name) on you, in \(Catalog.cities[c.city].name).") }
        s.carryCost[c.good] -= s.carryCost[c.good] * c.qty / s.carry[c.good]
        s.carry[c.good] -= c.qty
        s.cash += c.reward
        addDirty(&s, c.reward)
        s.rep = min(100, s.rep + 3)
        s.contracts = (s.contracts ?? []).filter { $0.id != id }
        s.stats.contractsDone = (s.stats.contractsDone ?? 0) + 1
        record(&s, c.reward, "Contract: \(c.qty) \(Catalog.goods[c.good].name) to \(Catalog.cities[c.city].name)")
        award(&s, "contract")
        s.lastBigWin = c.reward
        s.notice = "Job done. \(Money.gbp(c.reward)) in a carrier bag, no receipt."
    }

    static func expireContracts(_ s: inout GameState, lines: inout [String]) {
        guard let all = s.contracts else { return }
        var keep: [Contract] = []
        for c in all {
            if c.due < s.day {
                s.rep = max(0, s.rep - 6)
                lines.append("JOB FAILED: the buyer in \(Catalog.cities[c.city].name) waited for \(Catalog.goods[c.good].name) that never came. Your name is mud.")
            } else {
                keep.append(c)
            }
        }
        s.contracts = keep
    }

    // MARK: Endings

    enum Ending: String, CaseIterable { case walk, spain, score }

    struct EndingOption: Identifiable {
        let id: Ending
        let title: String
        let detail: String
        let available: Bool
        let reason: String?
    }

    static func endingOptions(_ s: GameState) -> [EndingOption] {
        let worth = netWorth(s)
        let debt = debt(s)
        let spainOK = debt == 0 && worth >= 1_000_000
        return [
            EndingOption(id: .spain, title: "Retire to Spain",
                         detail: "A villa, a boat, and a bar that’s never open. Clean exit, legend status.",
                         available: spainOK,
                         reason: spainOK ? nil : debt > 0 ? "Not with debts outstanding. They’d find you." : "You need £1,000,000 to disappear properly."),
            EndingOption(id: .score, title: "One last score",
                         detail: "Put half your cash into one enormous deal tonight. About \(Int(lastScoreChance(s) * 100))% it doubles. Otherwise you lose it and get nicked.",
                         available: s.cash >= 5_000, reason: s.cash >= 5_000 ? nil : "You need at least £5,000 for a deal worth doing."),
            EndingOption(id: .walk, title: "Walk away",
                         detail: "Count what you’ve got and call it a career.", available: true, reason: nil),
        ]
    }

    static func lastScoreChance(_ s: GameState) -> Double {
        clamp(0.45 + Double(s.rep - 50) / 250 - Double(s.heat) / 400 + (hasCrew(s, 2) ? 0.08 : 0), 0.2, 0.75)
    }

    static func chooseEnding(_ s: inout GameState, _ choice: Ending) {
        s.pendingEnding = nil
        // Hot enough and the police get there first.
        if s.heat >= 70, mode(s) != .tutorial, s.rng.chance(Double(s.heat - 55) / 70) {
            let seized = carriedValue(s)
            record(&s, -seized - min(s.cash, dirty(s) / 2), "Dawn raid on the last night")
            s.carry = s.carry.map { _ in 0 }
            s.carryCost = s.carryCost.map { _ in 0 }
            let lostCash = min(s.cash, dirty(s) / 2)
            s.cash -= lostCash
            let worth = netWorth(s)
            finish(&s, worth: worth, ending: "raid",
                   epitaph: "At 5am the door comes in. Armed police, a helicopter, a man from the BBC. They take \(Money.gbp(seized + lostCash)) and most of your dignity.")
            award(&s, "raided")
            return
        }
        switch choice {
        case .spain:
            finish(&s, worth: netWorth(s), ending: "spain",
                   epitaph: "Costa del Sol. You buy a bar, change your name to something with ‘Del’ in it, and never answer a British number again.")
            award(&s, "spain")
        case .score:
            let stake = s.cash / 2
            if s.rng.chance(lastScoreChance(s)) {
                s.cash += stake
                record(&s, stake, "One last score")
                finish(&s, worth: netWorth(s), ending: "score",
                       epitaph: "The deal of a lifetime goes off without a hitch. \(Money.gbp(stake)) richer, you vanish before anyone thinks to ask how.")
                award(&s, "last_score")
            } else {
                record(&s, -stake - carriedValue(s), "The last score went wrong")
                s.cash -= stake
                s.carry = s.carry.map { _ in 0 }
                s.carryCost = s.carryCost.map { _ in 0 }
                finish(&s, worth: netWorth(s), ending: "scorefail",
                       epitaph: "The buyer was a copper with a very good moustache. \(Money.gbp(stake)) and your freedom, gone in a car park.")
            }
        case .walk:
            let worth = netWorth(s)
            finish(&s, worth: worth, ending: "walk",
                   epitaph: mode(s) == .tutorial ? "Training’s over. The real thing won’t be this kind." : epitaph(worth))
        }
    }

    private static func finish(_ s: inout GameState, worth: Int, ending: String, epitaph: String) {
        s.encounters = []
        s.over = GameOver(worth: worth, rank: Catalog.rank(for: worth), died: false, epitaph: epitaph, ending: ending)
        s.stats.bestWorth = max(s.stats.bestWorth, worth)
        awardEnd(&s)
    }

    /// What the player picked, as a headline and one line of stakes, for the reveal before the case file.
    static func endingPitch(_ s: GameState, _ choice: Ending) -> (title: String, line: String) {
        switch choice {
        case .spain: ("Retire to Spain", "A one-way ticket and a name that isn’t yours.")
        case .score: ("One last score", "Half your cash, \(Money.gbp(s.cash / 2)), on one deal. About \(Int(lastScoreChance(s) * 100))% it goes your way.")
        case .walk: ("Walk away", "No last deal. Count it and call it a career.")
        }
    }

    /// A few lines of what happened that night, read before the case file. `before` is the state the choice was made from.
    static func endingStory(before: GameState, after: GameState) -> (lines: [String], verdict: String, good: Bool) {
        let city = Catalog.cities[before.city].name
        let stake = before.cash / 2
        switch after.over?.ending {
        case "raid":
            let taken = max(0, netWorth(before) - netWorth(after))
            return (["You made your choice. The police made theirs first.",
                     "At 4:58am a van with blacked-out windows parks across the road in \(city).",
                     "At 5am the door comes in. Armed police, a helicopter, a man from the BBC.",
                     "They take \(Money.gbp(taken)) and most of your dignity."], "RAIDED.", false)
        case "spain":
            return (["You pack one bag. The rest goes in the canal, the bin, or the car you torch behind the retail park.",
                     "An early flight out of \(city), under a name you practised in the mirror.",
                     "Three weeks later you own a bar on the Costa del Sol that is never, ever open.",
                     "Nobody from back home finds you. Eventually, they stop looking."], "RETIRED.", true)
        case "score":
            return (["Half your cash in a holdall: \(Money.gbp(stake)). A lock-up on an industrial estate outside \(city). Midnight.",
                     "The buyer is late. Then early. Then counting.",
                     "Every note is real. Every brick is there. Nobody blinks.",
                     "You drive away \(Money.gbp(stake)) richer and you’re gone before the sun comes up."], "CLEAN GETAWAY.", true)
        case "scorefail":
            return (["Half your cash in a holdall: \(Money.gbp(stake)). A car park behind a closed-down carpet warehouse in \(city). Midnight.",
                     "The buyer has a very good moustache and a lot of questions about ‘the supply chain’.",
                     "The holdall changes hands. Then the headlights come on. All of them.",
                     "Face down on wet tarmac, you hear your rights read out. Slowly. Twice."], "BUSTED.", false)
        default:
            return (["No last deal. No big goodbye.",
                     "You count it twice at the kitchen table: \(Money.gbp(after.over?.worth ?? netWorth(after))).",
                     "Then the burner goes in a drawer, and stays there."], "OUT.", (after.over?.worth ?? 0) > 0)
        }
    }

    static func endingTitle(_ ending: String?) -> String {
        switch ending {
        case "spain": "Retired to Spain"
        case "score": "One Last Score"
        case "scorefail": "Nicked on the Last Job"
        case "raid": "Dawn Raid"
        case "jail": "Banged Up"
        case "quit": "Couldn’t Hack It"
        default: "Thirty Days"
        }
    }
}

extension Engine {
    /// The player gives up mid-game. The file is closed on them, unkindly, and nothing counts for records.
    static func walkOut(_ s: inout GameState) {
        let worth = netWorth(s)
        let city = Catalog.cities[s.city].name
        let days = min(s.day, s.maxDay)
        var r = SplitMix(seed: s.seed ^ UInt64(s.day * 7_919))
        let verdicts = [
            "Lasted \(days) day\(days == 1 ? "" : "s"). Turns out you weren’t cut out for this world. The pharmacy counter at a big supermarket is hiring: steady hours, a name badge, and the only thing you’ll be pushing is a trolley.",
            "Folded on day \(days). The streets of \(city) won’t remember you. Try the supermarket pharmacy: the prescriptions are legal, the hours are sociable and nobody will ever try to rob you by the bins.",
            "You couldn’t hack it. Hand in the burner, delete the contacts and go and ask about that till job. The supermarket pharmacy does a nice line in loyalty points, which is the closest you’ll get to respect.",
            "Walked away on day \(days). Some people build empires; you’re more of a ‘would you like a bag for that?’ type. The pharmacy aisle at your local supermarket could use a steady pair of hands.",
            "Not everyone’s built for the dark. You were built for a high-vis tabard and a staff discount. The supermarket pharmacy closes at eight. You’ll love it.",
        ]
        s.over = GameOver(worth: worth, rank: Catalog.rank(for: worth), died: false,
                          epitaph: verdicts[Int(r.next() % UInt64(verdicts.count))], ending: "quit")
        s.encounters = []
        s.pendingEnding = nil
    }
}
