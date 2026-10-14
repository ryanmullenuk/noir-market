import Foundation

/// All game rules. Pure functions over `GameState`, deterministic for a given seed.
enum Engine {
    enum Failure: Error, Equatable, LocalizedError {
        case notEnoughCash, noSpace, noStock, nothingToSell, locked, busy, invalid(String)
        var errorDescription: String? {
            switch self {
            case .notEnoughCash: "Not enough cash."
            case .noSpace: "No room to carry that."
            case .noStock: "Nobody’s selling that much."
            case .nothingToSell: "You’re not holding any."
            case .locked: "That city needs the full game."
            case .busy: "Deal with what’s in front of you first."
            case .invalid(let why): why
            }
        }
    }

    // MARK: Setup

    static func setUp(_ s: inout GameState) {
        s.markets = Catalog.cities.map { city in
            var m = Market(price: [], supply: [], previous: [])
            for g in Catalog.goods {
                let p = Int(s.rng.uniform(Double(g.low), Double(g.high)) * city.factor(for: g.id))
                m.price.append(max(1, p))
                m.previous.append(max(1, p))
                m.supply.append(s.rng.int(80, 900))
            }
            return m
        }
        rollInformants(&s)
        s.story = newStory(&s)
        s.ticker = [headline(&s, city: s.city)]
        s.stats.bestWorth = netWorth(s)
    }

    // MARK: Derived values

    static func accessible(_ s: GameState, _ city: Int) -> Bool {
        s.fullAccess || city < Catalog.freeCityCount
    }

    static func accessibleCities(_ s: GameState) -> [Int] {
        Catalog.cities.indices.filter { accessible(s, $0) }
    }

    static func capacity(_ s: GameState) -> Int {
        Catalog.baseCarry + s.bags.reduce(0) { $0 + Catalog.bags[$1].slots }
    }

    static func carried(_ s: GameState) -> Int { s.carry.reduce(0, +) }
    static func space(_ s: GameState) -> Int { capacity(s) - carried(s) }
    static func vaultCapacity(_ s: GameState, _ city: Int) -> Int { Catalog.vaultLevels[s.vaultLevel[city]].capacity }
    static func vaultUsed(_ s: GameState, _ city: Int) -> Int { s.vault[city].reduce(0, +) }
    static func hasWeapons(_ s: GameState) -> Bool { s.weapons.contains { $0 > 0 } }

    static func bestWeapon(_ s: GameState) -> Weapon? {
        Catalog.weapons.filter { s.weapons[$0.id] > 0 }.max { $0.win < $1.win }
    }

    static func payoff(_ loan: Loan, day: Int) -> Int {
        let full = Int((Double(loan.principal) * loan.rate).rounded())
        let minimum = max(1, Int((Double(full) * 0.10).rounded()))
        let elapsed = day - loan.startDay
        let accrued = elapsed <= 0 ? minimum : max(minimum, Int((Double(full) * Double(elapsed) / Double(loan.term)).rounded()))
        return loan.principal + min(full, accrued)
    }

    static func debt(_ s: GameState) -> Int { s.loans.reduce(0) { $0 + payoff($1, day: s.day) } }

    static func lenderLimit(_ s: GameState, _ lender: Lender) -> Int {
        var limit = Double(lender.limit)
        if s.rep >= 51 { limit *= 1.25 }
        if s.rep >= 81 { limit *= 1.5 }
        return Int(limit)
    }

    static func netWorth(_ s: GameState) -> Int {
        var worth = s.cash + s.bank
        let here = s.markets[s.city]
        for g in Catalog.goods.indices {
            worth += s.carry[g] * here.price[g]
            for c in Catalog.cities.indices { worth += s.vault[c][g] * s.markets[c].price[g] }
        }
        for ship in s.shipments where !ship.intercepted {
            for g in ship.goods.indices { worth += ship.goods[g] * s.markets[ship.to].price[g] }
        }
        for w in Catalog.weapons { worth += s.weapons[w.id] * w.price / 2 }
        return worth - debt(s)
    }

    static func fare(_ s: GameState, to dest: Int) -> Int {
        let from = Catalog.cities[s.city], to = Catalog.cities[dest]
        var r = SplitMix(seed: s.seed ^ UInt64(s.day * 10_007 + s.city * 131 + dest))
        let base = 40 + from.distanceKm(to: to) * 0.34 + (from.needsFlight(to: to) ? 60 : 0)
        let jitter = 0.9 + Double(r.next() % 1000) / 1000 * 0.3
        return max(30, Int((base * jitter / 10).rounded()) * 10)
    }

    /// Price after slippage for trading `qty` against local supply.
    static func impact(qty: Int, supply: Int) -> Double {
        min(0.45, Double(qty) / Double(qty + supply + 150) * 0.9)
    }

    static func buyQuote(_ s: GameState, good: Int, qty: Int) -> Int {
        let m = s.markets[s.city]
        let i = impact(qty: qty, supply: m.supply[good])
        return Int((Double(m.price[good]) * Double(qty) * (1 + i / 2)).rounded())
    }

    static func sellQuote(_ s: GameState, good: Int, qty: Int) -> Int {
        let m = s.markets[s.city]
        let i = impact(qty: qty, supply: m.supply[good])
        return Int((Double(m.price[good]) * Double(qty) * (1 - i / 2)).rounded())
    }

    static func maxBuy(_ s: GameState, good: Int) -> Int {
        let m = s.markets[s.city]
        var hi = min(space(s), m.supply[good])
        var lo = 0
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if buyQuote(s, good: good, qty: mid) <= s.cash { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    static func doctorPrice(_ s: GameState, points: Int) -> Int { points * (120 + s.day * 12) }

    // MARK: Trading

    static func buy(_ s: inout GameState, good: Int, qty: Int) throws {
        try idle(s)
        guard qty > 0 else { throw Failure.invalid("Pick a quantity.") }
        guard qty <= s.markets[s.city].supply[good] else { throw Failure.noStock }
        guard qty <= space(s) else { throw Failure.noSpace }
        let cost = buyQuote(s, good: good, qty: qty)
        guard cost <= s.cash else { throw Failure.notEnoughCash }
        let i = impact(qty: qty, supply: s.markets[s.city].supply[good])
        s.cash -= cost
        s.carry[good] += qty
        s.carryCost[good] += cost
        s.markets[s.city].supply[good] -= qty
        s.markets[s.city].price[good] = max(1, Int(Double(s.markets[s.city].price[good]) * (1 + i * 0.6)))
        s.stats.unitsBought += qty
        traded(&s, value: cost)
        s.notice = "Bought \(qty) \(Catalog.goods[good].name) for \(Money.gbp(cost))."
    }

    static func sell(_ s: inout GameState, good: Int, qty: Int) throws {
        try idle(s)
        guard qty > 0, qty <= s.carry[good] else { throw Failure.nothingToSell }
        let value = sellQuote(s, good: good, qty: qty)
        let i = impact(qty: qty, supply: s.markets[s.city].supply[good])
        let basis = s.carryCost[good] * qty / s.carry[good]
        s.carryCost[good] -= basis
        s.carry[good] -= qty
        s.cash += value
        s.markets[s.city].supply[good] += qty
        s.markets[s.city].price[good] = max(1, Int(Double(s.markets[s.city].price[good]) * (1 - i * 0.8)))
        s.stats.unitsSold += qty
        s.stats.biggestSale = max(s.stats.biggestSale, value)
        traded(&s, value: value)
        if qty >= 40 { s.heat = min(100, s.heat + qty / 40) }
        let profit = value - basis
        s.notice = "Sold \(qty) \(Catalog.goods[good].name) for \(Money.gbp(value)). " +
            (profit >= 0 ? "\(Money.gbp(profit)) clean profit." : "A \(Money.gbp(-profit)) loss. It happens.")
    }

    private static func traded(_ s: inout GameState, value: Int) {
        s.tradedToday = true
        // Rep from trading is capped per day so it cannot be farmed with one-unit trades.
        if value >= 1_000, s.repFromTradesToday < 3 {
            s.repFromTradesToday += 1
            s.rep = min(100, s.rep + 1)
        }
    }

    // MARK: Stash

    static func stash(_ s: inout GameState, good: Int, qty: Int) throws {
        try idle(s)
        guard qty > 0, qty <= s.carry[good] else { throw Failure.nothingToSell }
        guard vaultUsed(s, s.city) + qty <= vaultCapacity(s, s.city) else { throw Failure.invalid("The lock-up is full.") }
        let basis = s.carryCost[good] * qty / s.carry[good]
        s.carryCost[good] -= basis
        s.carry[good] -= qty
        s.vault[s.city][good] += qty
    }

    static func retrieve(_ s: inout GameState, good: Int, qty: Int) throws {
        try idle(s)
        guard qty > 0, qty <= s.vault[s.city][good] else { throw Failure.nothingToSell }
        guard qty <= space(s) else { throw Failure.noSpace }
        s.vault[s.city][good] -= qty
        s.carry[good] += qty
        s.carryCost[good] += qty * s.markets[s.city].price[good]
    }

    static func upgradeVault(_ s: inout GameState) throws {
        try idle(s)
        let next = s.vaultLevel[s.city] + 1
        guard next < Catalog.vaultLevels.count else { throw Failure.invalid("Already a fortress.") }
        let cost = Catalog.vaultLevels[next].cost
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        s.vaultLevel[s.city] = next
    }

    static func ship(_ s: inout GameState, goods: [Int], to dest: Int) throws {
        try idle(s)
        guard dest != s.city else { throw Failure.invalid("Pick somewhere else.") }
        guard accessible(s, dest) else { throw Failure.locked }
        let units = goods.reduce(0, +)
        guard units > 0 else { throw Failure.invalid("Nothing to ship.") }
        for g in goods.indices where goods[g] > s.vault[s.city][g] { throw Failure.nothingToSell }
        let cost = shippingCost(s, goods: goods, to: dest)
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        for g in goods.indices { s.vault[s.city][g] -= goods[g] }
        let risk = interceptionRisk(s, to: dest)
        let lost = s.rng.chance(risk)
        s.shipments.append(Shipment(id: s.nextID, from: s.city, to: dest, goods: goods, arrives: s.day + 1, intercepted: lost))
        s.nextID += 1
        s.stats.shipmentsSent += 1
        s.notice = "Shipment of \(units) units leaves for \(Catalog.cities[dest].name). Arrives tomorrow, all being well."
    }

    static func shippingCost(_ s: GameState, goods: [Int], to dest: Int) -> Int {
        var value = 0
        for g in goods.indices { value += goods[g] * s.markets[s.city].price[g] }
        let km = Catalog.cities[s.city].distanceKm(to: Catalog.cities[dest])
        return Int((Double(value) * 0.05).rounded(.up)) + 150 + Int(km / 2)
    }

    static func interceptionRisk(_ s: GameState, to dest: Int) -> Double {
        let flight = Catalog.cities[s.city].needsFlight(to: Catalog.cities[dest])
        return min(0.35, 0.04 + Double(s.heat) / 400 + (flight ? 0.05 : 0))
    }

    // MARK: Finance

    static func deposit(_ s: inout GameState, _ amount: Int) throws {
        try idle(s)
        guard amount > 0, amount <= s.cash else { throw Failure.notEnoughCash }
        s.cash -= amount; s.bank += amount
    }

    static func withdraw(_ s: inout GameState, _ amount: Int) throws {
        try idle(s)
        guard amount > 0, amount <= s.bank else { throw Failure.invalid("The bank won’t give you money you don’t have.") }
        s.bank -= amount; s.cash += amount
    }

    static func borrow(_ s: inout GameState, lender: Int, amount: Int) throws {
        try idle(s)
        let l = Catalog.lenders[lender]
        guard !s.loans.contains(where: { $0.lender == lender }) else {
            throw Failure.invalid("\(l.name) wants the last one back before he lends you another penny.")
        }
        guard amount > 0, amount <= lenderLimit(s, l) else { throw Failure.invalid("\(l.name) laughs. Then stops laughing.") }
        s.loans.append(Loan(id: s.nextID, lender: lender, principal: amount, rate: l.rate, startDay: s.day, due: s.day + l.term, term: l.term))
        s.nextID += 1
        s.cash += amount
        s.stats.loansTaken += 1
        s.notice = "\(l.name) counts out \(Money.gbp(amount)). Due back on day \(s.day + l.term)."
    }

    /// Pays towards a loan. A full payoff clears it; part payments reduce principal without touching accrued interest.
    static func repay(_ s: inout GameState, loan id: Int, amount: Int) throws {
        guard let i = s.loans.firstIndex(where: { $0.id == id }) else { throw Failure.invalid("No such loan.") }
        guard amount > 0, amount <= s.cash else { throw Failure.notEnoughCash }
        let owed = payoff(s.loans[i], day: s.day)
        let name = Catalog.lenders[s.loans[i].lender].name
        if amount >= owed {
            s.cash -= owed
            s.loans.remove(at: i)
            s.rep = min(100, s.rep + 5)
            s.notice = "\(name) is paid in full. He almost looks disappointed."
        } else {
            let interest = owed - s.loans[i].principal
            let toPrincipal = max(0, amount - interest)
            if toPrincipal == 0 { throw Failure.invalid("That doesn’t even cover the interest (\(Money.gbp(interest))).") }
            s.cash -= amount
            // Keep accrued interest by shifting it into principal, then restart the clock fairly.
            s.loans[i].principal = owed - amount
            s.loans[i].startDay = s.day
            s.loans[i].rate = s.loans[i].rate * max(0.2, Double(s.loans[i].due - s.day) / Double(s.loans[i].term))
            s.notice = "Paid \(Money.gbp(amount)) to \(name). \(Money.gbp(s.loans[i].principal)) still owed."
        }
    }

    // MARK: Black market

    static func buyBag(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        guard !s.bags.contains(id) else { throw Failure.invalid("Already got one.") }
        let bag = Catalog.bags[id]
        guard s.cash >= bag.price else { throw Failure.notEnoughCash }
        s.cash -= bag.price
        s.bags.append(id)
    }

    static func buyWeapon(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        let w = Catalog.weapons[id]
        guard s.cash >= w.price else { throw Failure.notEnoughCash }
        s.cash -= w.price
        s.weapons[id] += 1
        s.heat = min(100, s.heat + max(1, w.heat / 3))
    }

    static func sellWeapon(_ s: inout GameState, _ id: Int) throws {
        try idle(s)
        guard s.weapons[id] > 0 else { throw Failure.nothingToSell }
        s.weapons[id] -= 1
        s.cash += Catalog.weapons[id].price / 2
    }

    static func buyPhone(_ s: inout GameState) throws {
        try idle(s)
        guard s.cash >= 500 else { throw Failure.notEnoughCash }
        s.cash -= 500
        s.phones += 1
    }

    static func heal(_ s: inout GameState, points: Int) throws {
        try idle(s)
        let pts = min(points, 100 - s.health)
        guard pts > 0 else { throw Failure.invalid("You’re as well as you’re going to get.") }
        let cost = doctorPrice(s, points: pts)
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        s.health += pts
    }

    // MARK: Hustle

    static func rollInformants(_ s: inout GameState) {
        s.informantPrice = Catalog.informants.map { s.rng.int($0.cost.lowerBound, $0.cost.upperBound) / 10 * 10 }
        s.informantUsed = [false, false, false]
    }

    static func payInformant(_ s: inout GameState, _ id: Int) throws -> Outcome {
        try idle(s)
        guard !s.informantUsed[id] else { throw Failure.invalid("They’ve said all they’re saying today.") }
        let info = Catalog.informants[id]
        let cost = s.informantPrice[id]
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        s.informantUsed[id] = true
        s.stats.tipsBought += 1
        if s.rng.chance(info.scamChance) {
            s.rep = max(0, s.rep - 1)
            return Outcome(title: "Played", text: info.scam, good: false)
        }
        // Every tip looks the same; only the informant’s reliability tells you how much to trust it.
        let cities = accessibleCities(s)
        let city = cities[s.rng.int(0, cities.count - 1)]
        let good = s.rng.int(0, Catalog.goods.count - 1)
        let up = s.rng.chance(0.5)
        let pct = (up ? 1 : -1) * s.rng.int(30, 60)
        if s.rng.chance(info.trust) {
            s.events.append(ActiveEvent(city: city, good: good, pct: pct, startsDay: s.day + 1, daysLeft: 2, title: "Tip"))
        }
        let name = Catalog.goods[good].name, place = Catalog.cities[city].name
        let line = up
            ? "\(place) is about to run dry on \(name). Tomorrow the price climbs, maybe a lot."
            : "Somebody in \(place) is about to dump \(name). Tomorrow it’ll be going cheap."
        return Outcome(title: info.name, text: "“\(line)” Reliability: about \(Int(info.trust * 100))%.", good: true)
    }

    // MARK: Contacts

    static func callContact(_ s: inout GameState) throws {
        try idle(s)
        guard s.phones > 0 else { throw Failure.invalid("You need a burner phone.") }
        guard !s.calledToday else { throw Failure.invalid("Nobody picks up twice in one day.") }
        s.phones -= 1
        s.calledToday = true
        let cities = accessibleCities(s)
        let city = cities[s.rng.int(0, cities.count - 1)]
        let good = s.rng.int(0, Catalog.goods.count - 1)
        let base = Double(s.markets[city].price[good])
        let qty = base > 5000 ? s.rng.int(2, 8) : base > 2000 ? s.rng.int(5, 16) : base > 800 ? s.rng.int(10, 30) : s.rng.int(25, 90)
        let buyUnit = base * s.rng.uniform(0.6, 0.85)
        let saleUnit = base * s.rng.uniform(1.05, 1.45)
        let buyCost = Int(buyUnit * Double(qty))
        let payout = Int(saleUnit * Double(qty) * 0.85)
        let odds: [Double] = s.rep < 30 ? [0.35, 0.25, 0.18, 0.18, 0.04]
            : s.rep <= 70 ? [0.45, 0.22, 0.14, 0.14, 0.05]
            : [0.55, 0.18, 0.10, 0.11, 0.06]
        s.deal = DealOffer(good: good, city: city, qty: qty, buyCost: buyCost, payout: max(payout, buyCost + 50), odds: odds)
    }

    static func takeDeal(_ s: inout GameState) throws -> Outcome {
        guard let deal = s.deal else { throw Failure.invalid("No deal on the table.") }
        guard s.cash >= deal.buyCost else { throw Failure.notEnoughCash }
        s.deal = nil
        s.cash -= deal.buyCost
        s.stats.dealsDone += 1
        let name = Catalog.goods[deal.good].name
        switch s.rng.pick(weights: deal.odds) {
        case 0:
            s.cash += deal.payout; s.rep = min(100, s.rep + 2)
            return Outcome(title: "Done Deal", text: "The \(name) moves without a hitch. \(Money.gbp(deal.payout)) lands in your hand.", good: true)
        case 1:
            let back = Int(Double(deal.buyCost) * s.rng.uniform(0.6, 1.0))
            s.cash += back
            return Outcome(title: "Short Changed", text: "The buyer pays light and blames “the economy”. You get \(Money.gbp(back)) back.", good: false)
        case 2:
            s.heat = min(100, s.heat + s.rng.int(12, 25)); s.rep = max(0, s.rep - 2)
            return Outcome(title: "Set Up", text: "The buyer was wearing a wire, badly. You walk away, the money and the \(name) don’t.", good: false)
        case 3:
            s.rep = max(0, s.rep - 2)
            return Outcome(title: "Scammed", text: "The van never turns up. Neither does your \(Money.gbp(deal.buyCost)).", good: false)
        default:
            let jackpot = Int(Double(deal.payout) * s.rng.uniform(1.4, 1.9))
            s.cash += jackpot; s.rep = min(100, s.rep + 4)
            return Outcome(title: "Jackpot", text: "A bidding war breaks out over your \(name). You walk away with \(Money.gbp(jackpot)).", good: true)
        }
    }

    static func hangUp(_ s: inout GameState) { s.deal = nil }

    // MARK: Helpers

    static func idle(_ s: GameState) throws {
        if s.over != nil || !s.encounters.isEmpty { throw Failure.busy }
    }

    static func headline(_ s: inout GameState, city: Int) -> String {
        let name = Catalog.cities[city].name
        let lines = Press.headlines[name] ?? ["MARKETS ARE QUIET"]
        return "\(name.uppercased()): \(lines[s.rng.int(0, lines.count - 1)])"
    }

    static func newStory(_ s: inout GameState) -> Story {
        if s.storyDeck.isEmpty {
            s.storyDeck = Array(repeating: true, count: 5) + Array(repeating: false, count: 5)
            s.rng.shuffle(&s.storyDeck)
        }
        let truth = s.storyDeck.removeLast()
        let template = Press.stories[s.rng.int(0, Press.stories.count - 1)]
        let cities = accessibleCities(s)
        let city = cities[s.rng.int(0, cities.count - 1)]
        let good = s.rng.int(0, Catalog.goods.count - 1)
        let text = Press.fill(template.text, city: Catalog.cities[city].name, good: Catalog.goods[good].name)
        return Story(city: city, good: good, kind: template.kind, text: text, isTrue: truth)
    }
}

extension SplitMix {
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func uniform(_ lo: Double, _ hi: Double) -> Double { lo + unit() * (hi - lo) }
    mutating func int(_ lo: Int, _ hi: Int) -> Int { hi <= lo ? lo : lo + Int(next() % UInt64(hi - lo + 1)) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func pick(weights: [Double]) -> Int {
        let total = weights.reduce(0, +)
        var r = unit() * total
        for (i, w) in weights.enumerated() {
            if r < w { return i }
            r -= w
        }
        return weights.count - 1
    }
    mutating func shuffle<T>(_ a: inout [T]) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, int(0, i)) }
    }
}
