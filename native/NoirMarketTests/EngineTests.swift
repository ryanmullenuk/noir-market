import Foundation
import Testing
@testable import NoirMarket

@MainActor
struct EngineTests {
    func fresh(seed: UInt64 = 7, full: Bool = false) -> GameState {
        GameState(seed: seed, city: 0, name: "Test", fullAccess: full)
    }

    @Test func startingState() {
        let s = fresh()
        #expect(s.cash == 2_500)
        #expect(s.day == 1)
        #expect(Engine.capacity(s) == Catalog.baseCarry)
        #expect(s.markets.count == Catalog.cities.count)
        #expect(Engine.netWorth(s) == 2_500)
        #expect(s.story != nil)
    }

    @Test func sameSeedSameGame() {
        var a = fresh(seed: 99), b = fresh(seed: 99)
        try? Engine.stay(&a); try? Engine.stay(&b)
        #expect(a == b)
    }

    @Test func buyAndSellConserveGoods() throws {
        var s = fresh()
        let good = cheapest(s)
        let qty = Engine.maxBuy(s, good: good)
        #expect(qty > 0)
        let quote = Engine.buyQuote(s, good: good, qty: qty)
        try Engine.buy(&s, good: good, qty: qty)
        #expect(s.cash == 2_500 - quote)
        #expect(s.carry[good] == qty)
        #expect(s.cash >= 0)
        try Engine.sell(&s, good: good, qty: qty)
        #expect(s.carry[good] == 0)
        #expect(s.carryCost[good] == 0)
        // Slippage means a round trip in the same market always loses a little.
        #expect(s.cash < 2_500)
    }

    @Test func cannotOverfillBag() {
        var s = fresh()
        s.cash = 10_000_000
        let good = cheapest(s)
        s.markets[0].supply[good] = 1000
        #expect(throws: Engine.Failure.noSpace) { try Engine.buy(&s, good: good, qty: Engine.capacity(s) + 1) }
    }

    @Test func lockedCitiesNeedUnlock() {
        var s = fresh()
        #expect(throws: Engine.Failure.locked) { try Engine.travel(&s, to: 8) }
        s.fullAccess = true
        s.cash = 10_000
        #expect(throws: Never.self) { try Engine.travel(&s, to: 8) }
    }

    @Test func freePlayNewsOnlyMentionsFreeCities() {
        var s = fresh()
        for _ in 0..<40 {
            s.encounters = []
            try? Engine.stay(&s)
            if let story = s.story { #expect(story.city < Catalog.freeCityCount) }
            #expect(s.events.allSatisfy { $0.city < Catalog.freeCityCount })
            if s.over != nil { break }
        }
    }

    @Test func storyDeckIsHalfTrue() {
        var s = fresh()
        var truths = 0
        s.storyDeck = []
        for _ in 0..<10 { if Engine.newStory(&s).isTrue { truths += 1 } }
        #expect(truths == 5)
    }

    @Test func oneLoanPerLenderAndRepayment() throws {
        var s = fresh()
        try Engine.borrow(&s, lender: 0, amount: 5_000)
        #expect(throws: (any Error).self) { try Engine.borrow(&s, lender: 0, amount: 1_000) }
        let owed = Engine.debt(s)
        #expect(owed > 5_000)
        try Engine.repay(&s, loan: s.loans[0].id, amount: owed)
        #expect(s.loans.isEmpty)
    }

    @Test func partPaymentCannotResetInterest() throws {
        var s = fresh()
        try Engine.borrow(&s, lender: 4, amount: 50_000)
        s.encounters = []
        s.day += 2
        let before = Engine.debt(s)
        #expect(throws: (any Error).self) { try Engine.repay(&s, loan: s.loans[0].id, amount: 1) }
        try Engine.repay(&s, loan: s.loans[0].id, amount: 30_000)
        #expect(Engine.debt(s) >= before - 30_000)
    }

    @Test func missedLoanSummonsCollector() {
        var s = fresh()
        try? Engine.borrow(&s, lender: 0, amount: 1_000)
        s.cash = 0
        for _ in 0..<5 {
            if !s.encounters.isEmpty { break }
            try? Engine.stay(&s)
        }
        #expect(s.encounters.contains { if case .collector = $0 { true } else { false } })
    }

    @Test func encountersBlockOtherActions() {
        var s = fresh()
        s.encounters = [.trouble(Trouble(attacker: 0, round: 1, runChance: 0.5, fightChance: 0.5, handOver: 100))]
        #expect(throws: Engine.Failure.busy) { try Engine.stay(&s) }
        #expect(throws: Engine.Failure.busy) { try Engine.buy(&s, good: 0, qty: 1) }
        try? Engine.resolve(&s, .handOver)
        #expect(s.encounters.isEmpty)
    }

    @Test func cleanPoliceStopCostsNothing() throws {
        var s = fresh()
        let cash = s.cash
        s.encounters = [.police(PoliceStop(airport: false, bribe: 1000, bribeChance: 0.5, runChance: 0.5, fightChance: 0.1, jail: 0, fine: 2000))]
        let outcome = try Engine.resolve(&s, .comply)
        #expect(outcome.good)
        #expect(s.cash == cash)
    }

    @Test func gameEndsAfterThirtyDays() {
        var s = fresh()
        var guardrail = 0
        while s.over == nil && guardrail < 200 {
            guardrail += 1
            if !s.encounters.isEmpty { try? Engine.resolve(&s, choice(for: s.encounters[0], s)); continue }
            try? Engine.stay(&s)
        }
        #expect(s.over != nil)
        #expect(s.day <= s.maxDay)
    }

    @Test func saveRoundTrips() throws {
        var s = fresh()
        try? Engine.stay(&s)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        #expect(back == s)
    }

    @Test func realTipMovesTomorrowsPrice() throws {
        // Pete is right ~94% of the time; over many seeds the tipped price should usually move the stated way.
        var hits = 0, total = 0
        for seed in 1...60 {
            var s = fresh(seed: UInt64(seed))
            s.cash = 100_000
            guard (try? Engine.payInformant(&s, 2)) != nil, let e = s.events.last, e.title == "Tip" else { continue }
            let before = s.markets[e.city].price[e.good]
            s.encounters = []
            try? Engine.stay(&s)
            let after = s.markets[e.city].price[e.good]
            total += 1
            if (e.pct > 0) == (after > before) { hits += 1 }
        }
        #expect(total > 30)
        #expect(Double(hits) / Double(total) > 0.75)
    }

    func cheapest(_ s: GameState) -> Int {
        Catalog.goods.indices.filter { s.markets[s.city].supply[$0] > 0 }.min { s.markets[s.city].price[$0] < s.markets[s.city].price[$1] }!
    }
}

/// A sensible default choice for any encounter, used by tests and the balance bot.
func choice(for encounter: Encounter, _ s: GameState) -> Choice { encounter.defaultChoice(s) }
