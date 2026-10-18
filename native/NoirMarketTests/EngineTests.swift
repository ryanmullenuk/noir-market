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

    @Test func nextMorningChecksIntelAndTips() throws {
        var s = fresh(seed: 42)
        s.cash = 100_000
        _ = try Engine.payInformant(&s, 2)
        let hadTip = !(s.pendingTips ?? []).isEmpty
        try Engine.stay(&s)
        let checks = s.report?.checks ?? []
        #expect(checks.contains { $0.contains("yesterday's intel") })
        if hadTip { #expect(checks.contains { $0.hasPrefix("TIP") }) }
        #expect((s.pendingTips ?? []).isEmpty)
    }

    @Test func lenderQuipMentionsTerms() throws {
        var s = fresh()
        try Engine.borrow(&s, lender: 1, amount: 5_000)
        let line = Engine.lenderQuip(&s, lender: 1, amount: 5_000)
        #expect(!line.isEmpty)
        #expect(!line.contains("{"))
    }

    @Test func godModeUnlocksEverythingAndNeverRunsDry() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = GameStore(directory: dir)
        let previous = store.playerName
        defer { store.playerName = previous }
        store.playerName = "godmode"
        store.newGame(city: 0)
        #expect(store.state?.godMode == true)
        #expect(store.state?.fullAccess == true)
        store.act { try Engine.buyBag(&$0, 3) }
        #expect(store.state?.cash == GameStore.godCash)
        store.act { try Engine.travel(&$0, to: 10) }
        #expect(store.state?.city == 10 || !(store.state?.encounters.isEmpty ?? true))
    }

    @Test func shipmentsWaitAtTheDepotUntilCollected() throws {
        var fates: [String: Int] = [:]
        for seed in 1...200 {
            var s = fresh(seed: UInt64(seed))
            s.cash = 100_000
            let good = cheapest(s)
            let q = min(10, Engine.maxBuy(s, good: good))
            guard q > 0 else { continue }
            try Engine.buy(&s, good: good, qty: q)
            var goods = Array(repeating: 0, count: Catalog.goods.count)
            goods[good] = q
            try Engine.ship(&s, goods: goods, to: 1)
            #expect(s.carry[good] == 0)
            let fate = s.shipments[0].fate ?? "?"
            fates[fate, default: 0] += 1
            s.encounters = []
            try Engine.stay(&s)
            s.encounters = []
            if fate == "stolen" { #expect(s.shipments.isEmpty); continue }
            #expect(s.shipments.first?.landed == true)
            // Can't collect from the wrong city.
            #expect(throws: (any Error).self) { try Engine.collect(&s, shipment: s.shipments[0].id) }
            s.city = 1
            let before = s.carry[good]
            try Engine.collect(&s, shipment: s.shipments[0].id)
            #expect(s.carry[good] > before)
            #expect(s.carry[good] - before <= q)
            if fate == "tipped" { #expect(s.encounters.contains { if case .police(let p) = $0 { p.depot == true } else { false } }) }
        }
        #expect((fates["clean"] ?? 0) > 100)
        #expect((fates["stolen"] ?? 0) + (fates["tipped"] ?? 0) + (fates["skimmed"] ?? 0) > 5)
    }

    @Test func missedShotsLetYouGoAgain() throws {
        var kept = 0
        for seed in 1...200 {
            var s = fresh(seed: UInt64(seed))
            s.weapons[4] = 1
            s.encounters = [.trouble(Trouble(attacker: 2, round: 1, runChance: 0.5, fightChance: 0.0, handOver: 100))]
            let o = try Engine.resolve(&s, .fight)
            if s.health > 0 {
                #expect(s.encounters.count == 1)
                if case .trouble(let t) = s.encounters[0] { #expect(t.round == 2) }
                #expect(o.title == "Missed")
                kept += 1
            }
        }
        #expect(kept > 150)
        var p = fresh()
        p.weapons[4] = 1
        p.encounters = [.police(PoliceStop(airport: false, bribe: 1000, bribeChance: 0.5, runChance: 0.5, fightChance: 0.0, jail: 0, fine: 500))]
        try Engine.resolve(&p, .fight)
        if case .police(let stop) = p.encounters.first { #expect(stop.round == 2) } else { Issue.record("expected a second round") }
        try Engine.resolve(&p, .comply)
        #expect(p.encounters.isEmpty)
        #expect(p.stats.jailDays >= 2)
    }

    @Test func dumpAndStashBeforeAFlight() {
        var s = fresh()
        s.carry[2] = 10; s.carryCost[2] = 1000; s.weapons[0] = 1
        Engine.stashAll(&s)
        #expect(s.carry[2] == 0 && s.vault[0][2] == 10)
        s.carry[3] = 5
        Engine.dumpAll(&s)
        #expect(Engine.carried(s) == 0 && !Engine.hasWeapons(s))
    }

    @Test func snitchesRingWithHalfPriceTips() throws {
        var rang = 0
        for seed in 1...300 {
            var s = fresh(seed: UInt64(seed))
            s.cash = 50_000
            try Engine.stay(&s)
            guard let call = s.call else { continue }
            rang += 1
            if call.caller < 3 { #expect(call.fee <= max(20, s.informantPrice[call.caller] / 2 + 10)) }
            Engine.answerCall(&s)
            #expect(s.call?.answered == true)
            let cash = s.cash
            _ = try Engine.acceptCall(&s)
            #expect(s.cash == cash - call.fee)
            #expect(s.call?.result != nil)
            Engine.declineCall(&s)
            #expect(s.call == nil)
        }
        #expect(rang > 30 && rang < 120)
    }

    @Test func dailySeedIsSharedAndFreeOnly() {
        var a = GameState(seed: GameMode.dailySeed(), city: 0, name: "A", fullAccess: true)
        var b = GameState(seed: GameMode.dailySeed(), city: 0, name: "B", fullAccess: false)
        Engine.configure(&a, mode: .daily, perk: .student)
        Engine.configure(&b, mode: .daily, perk: nil)
        #expect(a.fullAccess == false && a.perk == nil)
        #expect(a.markets == b.markets)
        try? Engine.stay(&a); try? Engine.stay(&b)
        #expect(a.markets == b.markets && a.story == b.story)
    }

    @Test func sprintEndsAfterSevenDays() {
        var s = fresh()
        Engine.configure(&s, mode: .sprint, perk: nil)
        #expect(s.maxDay == 7)
        var guardrail = 0
        while s.over == nil && guardrail < 100 {
            guardrail += 1
            if let e = s.encounters.first { _ = try? Engine.resolve(&s, e.defaultChoice(s)); continue }
            try? Engine.stay(&s)
        }
        #expect(s.over != nil && s.day <= 7)
        #expect(s.over?.died == true || (s.unlocked ?? []).contains("survive_sprint"))
    }

    @Test func perksChangeTheOdds() {
        var plain = fresh(), student = fresh(), docker = fresh(), copper = fresh()
        Engine.configure(&plain, mode: .standard, perk: nil)
        Engine.configure(&student, mode: .standard, perk: .student)
        Engine.configure(&docker, mode: .standard, perk: .docker)
        Engine.configure(&copper, mode: .standard, perk: .copper)
        #expect(Engine.fare(student, to: 1) < Engine.fare(plain, to: 1))
        #expect(Engine.interceptionRisk(docker, to: 1) < Engine.interceptionRisk(plain, to: 1))
        plain.carry[0] = 10; copper.carry[0] = 10
        let p1 = Engine.policeStop(&plain, airport: false), p2 = Engine.policeStop(&copper, airport: false)
        #expect(p2.bribe < p1.bribe && p2.bribeChance > p1.bribeChance)
    }

    @Test func tutorialScriptRunsAndGraduates() throws {
        var s = GameState(seed: 2026, city: 0, name: "T", fullAccess: false)
        Engine.configure(&s, mode: .tutorial, perk: nil)
        #expect(Engine.tutorialStep(s)?.title.contains("Buy") == true)
        let q = Engine.maxBuy(s, good: 6)
        try Engine.buy(&s, good: 6, qty: q)
        #expect(Engine.tutorialStep(s)?.title.contains("Travel") == true)
        try Engine.travel(&s, to: 1)
        #expect(s.encounters.contains { if case .police = $0 { true } else { false } })
        try Engine.resolve(&s, .bribe)
        s.encounters = []
        try Engine.sell(&s, good: 6, qty: s.carry[6])
        try Engine.stay(&s)
        s.encounters = []
        try Engine.stay(&s)
        #expect(s.over != nil)
        #expect((s.unlocked ?? []).contains("tutorial"))
    }

    @Test func rememberedPricesStopAtLastVisit() throws {
        var s = fresh()
        Engine.configure(&s, mode: .standard, perk: nil)
        s.cash = 50_000
        try Engine.travel(&s, to: 1)
        s.encounters = []
        let londonSeen = Engine.remembered(s, city: 0, good: 3)
        try Engine.stay(&s); s.encounters = []
        try Engine.stay(&s); s.encounters = []
        #expect(Engine.remembered(s, city: 0, good: 3) == londonSeen)
        #expect(Engine.remembered(s, city: 1, good: 3).count >= 3)
    }

    @Test func sellingOnTurfBringsTheCrew() throws {
        var visits = 0
        for seed in 1...60 {
            var s = fresh(seed: UInt64(seed))
            Engine.configure(&s, mode: .standard, perk: nil)
            s.city = 1 // Manchester: Moss Side Crew
            s.cash = 500_000
            for _ in 0..<6 {
                let g = cheapest(s)
                let q = min(25, Engine.maxBuy(s, good: g))
                if q > 0 { try Engine.buy(&s, good: g, qty: q); try Engine.sell(&s, good: g, qty: q) }
            }
            #expect(Engine.turf(s, 1) > 0)
            s.turf![1] = 90
            try Engine.stay(&s)
            if s.encounters.contains(where: { if case .trouble(let t) = $0 { t.crew != nil } else { false } }) { visits += 1 }
        }
        #expect(visits > 20)
        // No rivals in London.
        var l = fresh(); l.cash = 100_000
        let g = cheapest(l); let q = min(20, Engine.maxBuy(l, good: g))
        try Engine.buy(&l, good: g, qty: q); try Engine.sell(&l, good: g, qty: q)
        #expect(Engine.turf(l, 0) == 0)
    }

    @Test func frontsWashDirtyCashAndUnwashedCashDrawsHeat() throws {
        var s = fresh(), clean = fresh()
        s.cash = 400_000; s.dirty = 400_000; s.heat = 30
        clean.cash = 400_000; clean.dirty = 0; clean.heat = 30
        try Engine.stay(&s); s.encounters = []
        try Engine.stay(&clean)
        #expect(s.heat > clean.heat)
        try Engine.buyBusiness(&s, 2)
        let before = Engine.dirty(s)
        try Engine.stay(&s); s.encounters = []
        #expect(Engine.dirty(s) <= before - 40_000 + 1)
        #expect(Engine.netWorth(s) > s.cash + s.bank - Engine.debt(s))
    }

    @Test func unpaidCrewWalks() throws {
        var s = fresh()
        try Engine.hire(&s, 1)
        #expect(Engine.hasCrew(s, 1))
        s.cash = 0; s.bank = 0
        try Engine.stay(&s); s.encounters = []
        #expect(Engine.hasCrew(s, 1))
        try Engine.stay(&s); s.encounters = []
        #expect(!Engine.hasCrew(s, 1))
    }

    @Test func contractsPayAndExpire() throws {
        var s = fresh()
        Engine.configure(&s, mode: .standard, perk: nil)
        Engine.makeOffers(&s)
        let offer = try #require(s.offers?.first)
        try Engine.acceptContract(&s, offer.id)
        #expect(s.contracts?.count == 1)
        s.city = offer.city
        s.carry[offer.good] = offer.qty
        let cash = s.cash
        try Engine.deliver(&s, offer.id)
        #expect(s.cash == cash + offer.reward)
        #expect(s.contracts?.isEmpty == true)
        // A missed one costs reputation.
        var m = fresh(); Engine.makeOffers(&m)
        let o2 = try #require(m.offers?.first)
        try Engine.acceptContract(&m, o2.id)
        m.day = o2.due + 1
        let rep = m.rep
        var lines: [String] = []
        Engine.expireContracts(&m, lines: &lines)
        #expect(m.rep < rep && !lines.isEmpty)
    }

    @Test func lastNightOffersEndings() {
        var s = fresh()
        s.day = s.maxDay; s.heat = 0
        try? Engine.stay(&s)
        #expect(s.pendingEnding == true && s.over == nil)
        let spain = Engine.endingOptions(s).first { $0.id == .spain }!
        #expect(!spain.available)
        s.cash = 2_000_000
        #expect(Engine.endingOptions(s).first { $0.id == .spain }!.available)
        Engine.chooseEnding(&s, .spain)
        #expect(s.over?.ending == "spain")
        // Red-hot heat risks a raid.
        var raids = 0
        for seed in 1...100 {
            var r = fresh(seed: UInt64(seed)); r.day = r.maxDay; r.heat = 100
            try? Engine.stay(&r)
            Engine.chooseEnding(&r, .walk)
            if r.over?.ending == "raid" { raids += 1 }
        }
        #expect(raids > 40 && raids < 85)
    }

    @Test func backgroundsHaveDrawbacks() {
        var c = fresh(), st = fresh(), d = fresh()
        Engine.configure(&c, mode: .standard, perk: .copper)
        Engine.configure(&st, mode: .standard, perk: .student)
        Engine.configure(&d, mode: .standard, perk: .docker)
        #expect(c.rep == 0)
        #expect(st.cash == 1_500 && st.rep == 35)
        #expect(d.heat == 25 && d.rep == 40)
    }

    @Test func respectMovesPricesAndJobs() {
        var low = fresh(), high = fresh()
        low.rep = 0; high.rep = 100
        let g = cheapest(low)
        #expect(Engine.sellQuote(high, good: g, qty: 5) > Engine.sellQuote(low, good: g, qty: 5))
        #expect(Engine.buyQuote(high, good: g, qty: 5) < Engine.buyQuote(low, good: g, qty: 5))
        Engine.makeOffers(&low); Engine.makeOffers(&high)
        #expect((high.offers?.count ?? 0) > (low.offers?.count ?? 0))
        // Low respect draws bigger gangs.
        var lowGangs = 0, highGangs = 0
        for seed in 1...400 {
            var a = fresh(seed: UInt64(seed)); a.rep = 0
            var b = fresh(seed: UInt64(seed)); b.rep = 100
            if Engine.trouble(&a).attacker >= 2 { lowGangs += 1 }
            if Engine.trouble(&b).attacker >= 2 { highGangs += 1 }
        }
        #expect(lowGangs > highGangs * 2)
    }

    @Test func loyalSnitchesGetBetterStiffedOnesSellYouOut() throws {
        var s = fresh()
        s.cash = 1_000_000
        let base = Engine.trust(s, 0)
        for _ in 0..<5 {
            s.informantUsed = [false, false, false]
            _ = try Engine.payInformant(&s, 0)
        }
        #expect(Engine.loyalty(s, 0) > 80)
        #expect(Engine.trust(s, 0) > base)
        // Stiff Lucy until she's bitter, then she grasses.
        for _ in 0..<2 {
            s.informantUsed = [false, false, false]
            _ = try Engine.stiffInformant(&s, 1)
        }
        #expect(Engine.loyalty(s, 1) < 20)
        #expect(s.sellout == 1)
        s.carry[0] = 5
        try Engine.stay(&s)
        let stop = s.encounters.compactMap { if case .police(let p) = $0 { p } else { nil } }.first
        #expect(stop?.grass == "Lucy Loose Lips")
        #expect(s.sellout == nil)
    }

    @Test func testerOpensCitiesWithNormalMoney() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = GameStore(directory: dir)
        let previous = store.playerName
        defer { store.playerName = previous }
        store.playerName = "Tester"
        store.newGame(city: 9)
        #expect(store.state?.fullAccess == true)
        #expect(store.state?.godMode != true)
        #expect(store.state?.cash == 2_500)
        #expect(store.state?.city == 9)
        store.fullAccess = false
        #expect(store.state?.fullAccess == true)
    }

    @Test func longStaysBringRaidAlertsAndStashingKeepsYouClean() throws {
        // Over many seeds: five-plus nights in one city usually brings a Breaking News alert,
        // staying put after it usually brings a raid, and a stashed player walks away clean.
        var alerts = 0, raids = 0, clean = 0
        for seed in 1...40 {
            var s = fresh(seed: UInt64(seed))
            s.weapons[0] = 1
            s.carry[cheapest(s)] = 5
            s.streak = Engine.raidStreak
            s.encounters = []; s.call = nil
            Engine.maybeRaidAlert(&s)
            guard s.raid != nil else { continue }
            alerts += 1
            Engine.goToGround(&s)
            #expect(Engine.carried(s) == 0)
            #expect(!Engine.hasWeapons(s))
            #expect(Engine.stashedWeapons(s, s.city)[0] == 1)
            try Engine.stay(&s)
            if case .police(let stop)? = s.encounters.first, stop.raid == true {
                raids += 1
                let out = try Engine.resolve(&s, .comply)
                if out.good { clean += 1 }
            }
        }
        #expect(alerts >= 15)
        #expect(raids >= alerts / 2)
        #expect(clean == raids)

        // Moving on clears the warning.
        var t = fresh(seed: 3, full: true)
        t.raid = RaidAlert(city: t.city, day: t.day, seen: true)
        try Engine.travel(&t, to: 1)
        #expect(t.raid == nil || t.raid?.city == 1)
        #expect(!t.encounters.contains { if case .police(let p) = $0 { p.raid == true } else { false } })
        #expect(t.streak == 0)
    }

    func cheapest(_ s: GameState) -> Int {
        Catalog.goods.indices.filter { s.markets[s.city].supply[$0] > 0 }.min { s.markets[s.city].price[$0] < s.markets[s.city].price[$1] }!
    }
}

/// A sensible default choice for any encounter, used by tests and the balance bot.
func choice(for encounter: Encounter, _ s: GameState) -> Choice { encounter.defaultChoice(s) }
