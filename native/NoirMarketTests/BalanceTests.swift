import Foundation
import Testing
@testable import NoirMarket

/// Plays many games with a simple trader bot and prints the spread of results.
/// The assertions are loose guard rails; the printed table is what's used to tune balance.
@MainActor
struct BalanceTests {
    struct Result { var worth: Int; var died: Bool }

    static func play(seed: UInt64, full: Bool, careful: Bool) -> Result {
        var s = GameState(seed: seed, city: 0, name: "Bot", fullAccess: full)
        var r = SplitMix(seed: seed &* 31)
        var steps = 0
        while s.over == nil && steps < 2_000 {
            steps += 1
            if !s.encounters.isEmpty { _ = try? Engine.resolve(&s, choice(for: s.encounters[0], s)); continue }
            s.outcome = nil
            // Sell anything worth more here than it cost.
            for g in Catalog.goods.indices where s.carry[g] > 0 {
                let unit = Engine.sellQuote(s, good: g, qty: s.carry[g]) / s.carry[g]
                let cost = s.carryCost[g] / max(1, s.carry[g])
                if unit > cost || s.day == s.maxDay { try? Engine.sell(&s, good: g, qty: s.carry[g]) }
            }
            if careful, s.health < 50 { try? Engine.heal(&s, points: 30) }
            if s.cash > 30_000, !s.bags.contains(1) { try? Engine.buyBag(&s, 1) }
            if s.cash > 8_000, !s.bags.contains(0) { try? Engine.buyBag(&s, 0) }
            if careful, s.cash > 5_000, s.weapons[0] == 0 { try? Engine.buyWeapon(&s, 0) }
            // Buy the most underpriced good.
            if s.day < s.maxDay {
                let city = Catalog.cities[s.city]
                let candidates = Catalog.goods.indices.filter { s.markets[s.city].supply[$0] > 0 }
                if let best = candidates.min(by: { a, b in
                    Double(s.markets[s.city].price[a]) / (Catalog.goods[a].mid * city.factor(for: a)) <
                    Double(s.markets[s.city].price[b]) / (Catalog.goods[b].mid * city.factor(for: b))
                }) {
                    let ratio = Double(s.markets[s.city].price[best]) / (Catalog.goods[best].mid * city.factor(for: best))
                    if ratio < 0.8 {
                        let budget = s.cash - 600
                        var q = Engine.maxBuy(s, good: best)
                        while q > 0 && Engine.buyQuote(s, good: best, qty: q) > budget { q -= 1 }
                        if q > 0 { try? Engine.buy(&s, good: best, qty: q) }
                    }
                }
            }
            if careful, s.cash > 50_000 { try? Engine.deposit(&s, s.cash - 20_000) }
            let options = Engine.accessibleCities(s).filter { $0 != s.city && Engine.fare(s, to: $0) < s.cash }
            if let dest = options.isEmpty ? nil : options[r.int(0, options.count - 1)] {
                try? Engine.travel(&s, to: dest)
            } else {
                try? Engine.stay(&s)
            }
        }
        return Result(worth: s.over?.worth ?? Engine.netWorth(s), died: s.over?.died ?? false)
    }

    @Test(arguments: [false, true])
    func balance(full: Bool) {
        for careful in [false, true] {
            let results = (1...400).map { Self.play(seed: UInt64($0) * 7_919, full: full, careful: careful) }
            let worths = results.map(\.worth).sorted()
            let deaths = results.filter(\.died).count
            let pct = { (p: Double) in worths[min(worths.count - 1, Int(Double(worths.count) * p))] }
            let ranks = Dictionary(grouping: worths, by: { Catalog.ranks[Catalog.rank(for: $0)].name }).mapValues(\.count)
            print("BALANCE full=\(full) careful=\(careful): p10=\(pct(0.1)) p25=\(pct(0.25)) median=\(pct(0.5)) p75=\(pct(0.75)) p90=\(pct(0.9)) deaths=\(deaths)/400 ranks=\(ranks)")
            #expect(deaths < 80)
            #expect(pct(0.5) > 2_500)
        }
    }
}
