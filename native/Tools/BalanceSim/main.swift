import Foundation
// Balance harness: swiftc -O NoirMarket/Model/*.swift NoirMarket/Engine/*.swift Tools/BalanceSim/main.swift
func choose(_ e: Encounter, _ s: GameState) -> Choice { e.defaultChoice(s) }
func play(seed: UInt64, full: Bool, careful: Bool, borrow: Bool, perk: Perk? = nil) -> (Int, Bool, Int) {
    var s = GameState(seed: seed, city: 0, name: "Bot", fullAccess: full)
    Engine.configure(&s, mode: .standard, perk: perk)
    var r = SplitMix(seed: seed &* 31)
    var steps = 0, encounters = 0
    if borrow { try? Engine.borrow(&s, lender: 0, amount: 8_000) }
    while s.over == nil && steps < 2_000 {
        steps += 1
        if !s.encounters.isEmpty { encounters += 1; _ = try? Engine.resolve(&s, choose(s.encounters[0], s)); continue }
        for g in Catalog.goods.indices where s.carry[g] > 0 {
            let unit = Engine.sellQuote(s, good: g, qty: s.carry[g]) / s.carry[g]
            let cost = s.carryCost[g] / max(1, s.carry[g])
            if unit > cost || s.day == s.maxDay { try? Engine.sell(&s, good: g, qty: s.carry[g]) }
        }
        if s.pendingEnding == true { Engine.chooseEnding(&s, .walk); continue }
        if s.cash < 300, Engine.carried(s) == 0, s.loans.isEmpty, s.day < 25 { try? Engine.borrow(&s, lender: 0, amount: 5_000) }
        for l in s.loans where s.cash > Engine.payoff(l, day: s.day) + 1000 { try? Engine.repay(&s, loan: l.id, amount: Engine.payoff(l, day: s.day)) }
        if careful, s.health < 50 { try? Engine.heal(&s, points: 30) }
        if s.cash > 30_000, !s.bags.contains(1) { try? Engine.buyBag(&s, 1) }
        if s.cash > 8_000, !s.bags.contains(0) { try? Engine.buyBag(&s, 0) }
        if careful, s.cash > 5_000, s.weapons[0] == 0 { try? Engine.buyWeapon(&s, 0) }
        if s.day < s.maxDay {
            let city = Catalog.cities[s.city]
            let cands = Catalog.goods.indices.filter { s.markets[s.city].supply[$0] > 0 }
            let ratio = { (g: Int) in Double(s.markets[s.city].price[g]) / (Catalog.goods[g].mid * city.factor(for: g)) }
            if let best = cands.min(by: { ratio($0) < ratio($1) }), ratio(best) < 0.8 {
                let budget = s.cash - 600
                var q = Engine.maxBuy(s, good: best)
                while q > 0 && Engine.buyQuote(s, good: best, qty: q) > budget { q -= 1 }
                if q > 0 { try? Engine.buy(&s, good: best, qty: q) }
            }
        }
        if careful, s.cash > 50_000 { try? Engine.deposit(&s, s.cash - 20_000) }
        let opts = Engine.accessibleCities(s).filter { $0 != s.city && Engine.fare(s, to: $0) < s.cash }
        if s.day < s.maxDay, !opts.isEmpty { try? Engine.travel(&s, to: opts[r.int(0, opts.count - 1)]) } else { try? Engine.stay(&s) }
    }
    return (s.over?.worth ?? Engine.netWorth(s), s.over?.died ?? false, encounters)
}
for full in [false, true] { for careful in [false, true] { for borrow in [false, true] {
    let res = (1...600).map { play(seed: UInt64($0) * 7919, full: full, careful: careful, borrow: borrow) }
    let w = res.map(\.0).sorted()
    let p = { (q: Double) in w[min(w.count - 1, Int(Double(w.count) * q))] }
    let deaths = res.filter(\.1).count
    let enc = Double(res.map(\.2).reduce(0, +)) / Double(res.count)
    var ranks = [String: Int]()
    for x in w { ranks[Catalog.ranks[Catalog.rank(for: x)].name, default: 0] += 1 }
    print("full=\(full) careful=\(careful) borrow=\(borrow): p10=\(p(0.1)) p25=\(p(0.25)) med=\(p(0.5)) p75=\(p(0.75)) p90=\(p(0.9)) max=\(w.last!) deaths=\(deaths)/600 enc/game=\(String(format: "%.1f", enc)) \(ranks.sorted { $0.key < $1.key })")
}}}

for perk in [nil] + Perk.allCases.map(Optional.some) {
    let w = (1...600).map { play(seed: UInt64($0) * 7919, full: false, careful: true, borrow: false, perk: perk).0 }.sorted()
    print("perk \(perk?.rawValue ?? "none"): p25=\(w[150]) med=\(w[300]) p75=\(w[450])")
}
