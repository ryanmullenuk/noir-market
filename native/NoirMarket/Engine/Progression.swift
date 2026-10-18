import Foundation

extension Engine {
    // MARK: Modes and perks

    /// Applies a mode and perk to a fresh game.
    static func configure(_ s: inout GameState, mode: GameMode, perk: Perk?) {
        s.mode = mode.rawValue
        s.maxDay = mode.days
        s.perk = mode == .daily || mode == .tutorial ? nil : perk?.rawValue
        if let p = Engine.perk(s) {
            s.cash += p.start.cashDelta
            s.rep = p.start.respect
            s.heat = p.start.heat
        }
        if mode == .daily { s.fullAccess = false }
        if mode == .tutorial { setUpTutorial(&s) }
        recordHistory(&s)
    }

    // MARK: Respect

    /// -1 (no respect) … +1 (full respect), 0 at the default 50.
    static func respect(_ s: GameState) -> Double { Double(s.rep - 50) / 50 }

    static func changeRespect(_ s: inout GameState, _ delta: Int) {
        s.rep = min(100, max(0, s.rep + delta))
    }

    static func mode(_ s: GameState) -> GameMode { GameMode(rawValue: s.mode ?? "") ?? .standard }
    static func perk(_ s: GameState) -> Perk? { s.perk.flatMap(Perk.init(rawValue:)) }

    // MARK: Achievements

    /// Records a deal's result for the end-of-game rundown.
    static func record(_ s: inout GameState, _ amount: Int, _ text: String) {
        if amount > (s.stats.bestDeal ?? 0) { s.stats.bestDeal = amount; s.stats.bestDealText = text }
        if amount < 0 {
            s.stats.totalLost = (s.stats.totalLost ?? 0) - amount
            if amount < (s.stats.worstLoss ?? 0) { s.stats.worstLoss = amount; s.stats.worstLossText = text }
        }
    }

    static func award(_ s: inout GameState, _ id: String) {
        if !(s.stats.earned ?? []).contains(id) { s.stats.earned = (s.stats.earned ?? []) + [id] }
        guard !(s.unlocked ?? []).contains(id) else { return }
        s.unlocked = (s.unlocked ?? []) + [id]
    }

    static func awardEnd(_ s: inout GameState) {
        guard let over = s.over else { return }
        let m = mode(s)
        if m == .tutorial { award(&s, "tutorial"); return }
        guard !over.died else { return }
        switch m {
        case .sprint: award(&s, "survive_sprint")
        case .long: award(&s, "survive_long")
        case .daily: award(&s, "daily_done")
        default: award(&s, "survive_standard")
        }
        if s.stats.arrests == 0 && s.stats.bribesPaid == 0 { award(&s, "clean_hands") }
    }

    // MARK: Market history

    static func recordHistory(_ s: inout GameState) {
        var h = s.history ?? Array(repeating: Array(repeating: [Int](), count: Catalog.goods.count), count: Catalog.cities.count)
        for c in Catalog.cities.indices {
            for g in Catalog.goods.indices {
                h[c][g].append(s.markets[c].price[g])
                if h[c][g].count > 7 { h[c][g].removeFirst(h[c][g].count - 7) }
            }
        }
        s.history = h
        s.stats.worthByDay = (s.stats.worthByDay ?? []) + [netWorth(s)]
        if !(s.visited ?? []).contains(s.city) { s.visited = (s.visited ?? []) + [s.city] }
        var seen = s.seenDay ?? Array(repeating: 0, count: Catalog.cities.count)
        seen[s.city] = s.day
        s.seenDay = seen
    }

    /// What you remember of a city's prices for a good: the history up to your last visit.
    static func remembered(_ s: GameState, city: Int, good: Int) -> [Int] {
        guard let h = s.history?[city][good], !h.isEmpty else { return [] }
        let ago = max(0, s.day - (s.seenDay?[city] ?? s.day))
        return Array(h.dropLast(min(ago, h.count - 1)))
    }

    // MARK: Weather and events

    /// Rolls today's weather here and any scheduled events, and moves prices for them.
    static func rollWeatherAndEvents(_ s: inout GameState) -> [String] {
        let wet = ["Manchester", "Glasgow", "Cardiff", "Belfast", "Cork"].contains(Catalog.cities[s.city].name)
        let r = s.rng.unit()
        s.weather = r < (wet ? 0.5 : 0.32) ? "rain" : r < (wet ? 0.65 : 0.45) ? "fog" : "clear"
        var notes: [String] = []
        let cities = accessibleCities(s)
        // Festival weekends: days 6–7, 13–14, 20–21…
        if s.day % 7 == 6 || s.day % 7 == 0 {
            let c = cities[(s.day / 7) % cities.count]
            for g in [2, 7, 8] { s.markets[c].price[g] = Int(Double(s.markets[c].price[g]) * 1.5) }
            notes.append("festival:\(c)")
        }
        // Match day: Cardiff if you can get there, otherwise a Manchester derby.
        if s.day % 5 == 3 {
            let c = cities.contains(7) ? 7 : 1
            for g in [0, 12, 13] { s.markets[c].price[g] = Int(Double(s.markets[c].price[g]) * 1.35) }
            notes.append("match:\(c)")
        }
        s.todayEvents = notes
        return notes.map(eventHeadline)
    }

    static func eventHeadline(_ e: String) -> String {
        let parts = e.split(separator: ":")
        let city = Catalog.cities[Int(parts[1]) ?? 0].name
        switch parts[0] {
        case "festival": return "\(city.uppercased()): FESTIVAL WEEKEND. Pills, acid and MDA are flying out of every tent; prices up by half."
        default:
            return city == "Cardiff"
                ? "CARDIFF: MATCH DAY. Eighty thousand in red, every one of them ‘just out for the rugby’. Speed, coke and weed in demand; police everywhere."
                : "MANCHESTER: DERBY DAY. Half the city is crying, the other half wants a party. Speed, coke and weed in demand; police everywhere."
        }
    }

    static func eventHere(_ s: GameState, _ kind: String) -> Bool {
        (s.todayEvents ?? []).contains("\(kind):\(s.city)")
    }

    // MARK: Tutorial

    static let tutorialCity = 0

    static func setUpTutorial(_ s: inout GameState) {
        s.city = tutorialCity
        s.cash = 2_500
        // Kat is cheap in London today and about to soar in Manchester.
        let kat = 6
        s.markets[0].price[kat] = 90
        // Only 20 on the street, so buying the lot still leaves the train fare.
        s.markets[0].supply[kat] = 20
        s.events.append(ActiveEvent(city: 1, good: kat, pct: 90, startsDay: 2, daysLeft: 2, title: "Tip"))
        s.storyDeck = [false, true]
        s.notice = "Training day. Do what the green card says and you’ll be fine. Probably."
    }

    /// The guidance card shown at the top of the market in the tutorial.
    static func tutorialStep(_ s: GameState) -> (title: String, text: String)? {
        guard mode(s) == .tutorial, s.over == nil else { return nil }
        switch s.day {
        case 1 where s.stats.unitsBought == 0:
            return ("Step 1 · Buy", "Kat is going cheap here today. Tap Kat in the market, slide to Max and buy.")
        case 1:
            return ("Step 2 · Travel", "Word is Manchester is crying out for Kat. Tap Travel, pick MANCHESTER and go. Every trip takes a night.")
        case 2 where s.stats.unitsSold == 0:
            return ("Step 3 · Sell", "You survived your first stop and read your first NOIRNET feed. Kat is dear here now: tap it and sell the lot.")
        case 2:
            return ("Step 4 · Lie low", "Nicely done. Tap Lie Low Tonight to let the heat cool off. Tomorrow’s NOIRNET will tell you if yesterday’s intel was true.")
        default:
            return ("Last day", "That’s the basics. Stash, ship, borrow and pick up the phone to go further. Tap End It Here to finish training.")
        }
    }
}

extension Engine {
    /// A rough guide to what your bag would fetch in another city: the last price you saw there,
    /// or for somewhere you've never been, the going rate adjusted for what that city wants.
    static func bagEstimate(_ s: GameState, at city: Int) -> (value: Int, guessed: Bool) {
        var total = 0, guessed = false
        for g in Catalog.goods.indices where s.carry[g] > 0 {
            if let seen = remembered(s, city: city, good: g).last, seen > 0 {
                total += seen * s.carry[g]
            } else {
                total += Int(Catalog.goods[g].mid * Catalog.cities[city].factor(for: g)) * s.carry[g]
                guessed = true
            }
        }
        return (total, guessed)
    }
}
