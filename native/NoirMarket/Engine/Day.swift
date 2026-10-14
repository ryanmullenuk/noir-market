import Foundation

extension Engine {
    // MARK: Moving on

    static func travel(_ s: inout GameState, to dest: Int) throws {
        try idle(s)
        guard dest != s.city else { return try stay(&s) }
        guard accessible(s, dest) else { throw Failure.locked }
        let cost = fare(s, to: dest)
        guard s.cash >= cost else { throw Failure.notEnoughCash }
        s.cash -= cost
        let flight = Catalog.cities[s.city].needsFlight(to: Catalog.cities[dest])
        let from = Catalog.cities[s.city].name
        s.city = dest
        s.stats.trips += 1
        advance(&s, travelled: true, flight: flight,
                opening: "\(flight ? "You fly" : "You take the late train") from \(from) to \(Catalog.cities[dest].name). \(Money.gbp(cost)) well spent, probably.")
    }

    static func stay(_ s: inout GameState) throws {
        try idle(s)
        s.stats.nightsIn += 1
        let lowProfile = !s.tradedToday
        advance(&s, travelled: false, flight: false,
                opening: lowProfile ? "You keep your head down in \(Catalog.cities[s.city].name). The heat cools off a little."
                                    : "Another night in \(Catalog.cities[s.city].name).")
        if lowProfile { s.heat = max(0, s.heat - 4) }
    }

    /// The overnight tick. Moves every market, the news cycle, debts, shipments and the dangers of the street.
    static func advance(_ s: inout GameState, travelled: Bool, flight: Bool, opening: String) {
        var lines = [opening]
        let carrying = carried(s) > 0
        let yesterday = s.story

        tick(&s, lines: &lines)

        // Yesterday's story either comes good or turns out to be nonsense. Nobody tells you which.
        if let story = yesterday, story.isTrue { applyStory(&s, story, lines: &lines) }

        // Heat drifts: up while you carry, down while you’re clean.
        if carrying { s.heat = min(100, s.heat + s.rng.int(1, 4)) } else { s.heat = max(0, s.heat - s.rng.int(2, 6)) }
        let armed = s.weapons.enumerated().filter { $0.element > 0 }.count
        s.heat = min(100, s.heat + armed / 2)

        // Street dangers: at most one encounter a night.
        if s.encounters.isEmpty {
            let weapons = hasWeapons(s)
            let value = Double(carriedValue(s))
            var police = 0.015 + Double(s.heat) / 260 + (carrying ? 0.035 + min(0.04, value / 500_000) : 0) + (weapons ? 0.03 : 0)
            if flight && (carrying || weapons) { police += 0.08 + (weapons ? 0.08 : 0) }
            let worthRobbing = s.cash > 200 || carrying
            let mugging = worthRobbing ? 0.06 + (s.cash > 20_000 ? 0.04 : 0) + (s.rep < 20 ? 0.03 : 0) : 0
            let r = s.rng.unit()
            if r < police, carrying || weapons || s.heat > 60 {
                s.encounters.append(.police(policeStop(&s, airport: flight)))
            } else if r < police + mugging {
                s.encounters.append(.trouble(Engine.trouble(&s)))
            } else if r < police + mugging + 0.06 {
                friendGift(&s, lines: &lines)
            }
        }

        s.report = DayReport(day: s.day, city: s.city, travelled: travelled,
                             headline: s.ticker.first ?? "", story: s.story?.text ?? "", lines: lines)
        s.notice = lines.last ?? opening
        checkEnd(&s)
    }

    /// One day passing: prices, events, loans, shipments, rank. No encounters (also used for jail time).
    static func tick(_ s: inout GameState, lines: inout [String]) {
        s.day += 1
        s.tradedToday = false
        s.repFromTradesToday = 0
        s.calledToday = false
        s.deal = nil
        s.health = min(100, s.health + 2)
        walkPrices(&s)
        tickEvents(&s)

        // Fresh news: one or two price events somewhere you can actually reach.
        var ticker: [String] = []
        let count = s.rng.chance(0.55) ? 2 : 1
        let cities = accessibleCities(s)
        for _ in 0..<count {
            let template = Press.events[s.rng.int(0, Press.events.count - 1)]
            guard let good = Catalog.good(named: template.good) else { continue }
            let city = cities[s.rng.int(0, cities.count - 1)]
            applyShock(&s, city: city, good: good.id, pct: template.pct)
            s.events.append(ActiveEvent(city: city, good: good.id, pct: template.pct, startsDay: s.day + 1, daysLeft: template.days - 1, title: template.title))
            ticker.append("\(Catalog.cities[city].name.uppercased()): \(template.title.uppercased()). \(template.text)")
        }
        ticker.append(headline(&s, city: s.city))
        s.ticker = ticker
        s.story = newStory(&s)
        rollInformants(&s)

        // Shipments land.
        for i in s.shipments.indices.reversed() where s.shipments[i].arrives <= s.day {
            let ship = s.shipments[i]
            let units = ship.goods.reduce(0, +)
            if ship.intercepted {
                lines.append("Customs opened your crate bound for \(Catalog.cities[ship.to].name). \(units) units gone. Nobody signed for it, luckily.")
                s.stats.shipmentsLost += 1
                s.shipments.remove(at: i)
            } else if vaultUsed(s, ship.to) + units <= vaultCapacity(s, ship.to) {
                for g in ship.goods.indices { s.vault[ship.to][g] += ship.goods[g] }
                lines.append("Your shipment of \(units) units is safe in the \(Catalog.cities[ship.to].name) lock-up.")
                s.shipments.remove(at: i)
            } else if s.shipments[i].arrives == s.day {
                lines.append("Your shipment is waiting at the \(Catalog.cities[ship.to].name) depot. The lock-up is full.")
            }
        }

        // Debts.
        for i in s.loans.indices where s.loans[i].due < s.day {
            let owed = payoff(s.loans[i], day: s.day)
            s.loans[i].principal = Int(Double(owed) * 1.2)
            s.loans[i].rate = 0
            s.loans[i].startDay = s.day
            s.loans[i].due = s.day
            s.loans[i].missed += 1
            s.rep = max(0, s.rep - 8)
            s.heat = min(100, s.heat + 4)
            let name = Catalog.lenders[s.loans[i].lender].name
            lines.append("You missed \(name)’s payment. The debt grows by 20%.")
            if !s.encounters.contains(where: { if case .collector = $0 { true } else { false } }) {
                s.encounters.append(.collector(Collector(loan: s.loans[i].id, owed: s.loans[i].principal)))
            }
        }
        for loan in s.loans where loan.due == s.day {
            lines.append("\(Catalog.lenders[loan.lender].name) expects \(Money.gbp(payoff(loan, day: s.day))) today.")
        }

        updateRank(&s)
        s.stats.bestWorth = max(s.stats.bestWorth, netWorth(s))
    }

    // MARK: Markets

    static func walkPrices(_ s: inout GameState) {
        for c in Catalog.cities.indices {
            let city = Catalog.cities[c]
            for g in Catalog.goods {
                let f = city.factor(for: g.id)
                let old = Double(s.markets[c].price[g.id])
                let target = s.rng.uniform(Double(g.low), Double(g.high)) * f
                var p = (old + target) / 2 * s.rng.uniform(0.9, 1.1)
                p = min(max(p, Double(g.low) * f * 0.4), Double(g.high) * f * 2.5)
                s.markets[c].previous[g.id] = Int(old)
                s.markets[c].price[g.id] = max(1, Int(p))
                var supply = Double(s.markets[c].supply[g.id]) * s.rng.uniform(0.8, 1.2) + Double(s.rng.int(-80, 90))
                if s.rng.chance(0.05) { supply = 0 } // dry today
                s.markets[c].supply[g.id] = Int(min(1200, max(0, supply)))
            }
            // Reputation opens doors with the bigger suppliers.
            if s.rep >= 81, c == s.city {
                for g in Catalog.goods.indices { s.markets[c].supply[g] = min(1500, Int(Double(s.markets[c].supply[g]) * 1.12) + 25) }
            }
        }
    }

    static func applyShock(_ s: inout GameState, city: Int, good: Int, pct: Int) {
        let m = 1 + Double(pct) / 100
        s.markets[city].price[good] = max(1, Int(Double(s.markets[city].price[good]) * m))
        if pct > 0 {
            s.markets[city].supply[good] = Int(Double(s.markets[city].supply[good]) * s.rng.uniform(0.45, 0.78))
        } else {
            s.markets[city].supply[good] = min(1600, Int(Double(s.markets[city].supply[good]) * s.rng.uniform(1.2, 1.7)) + s.rng.int(30, 180))
        }
    }

    static func tickEvents(_ s: inout GameState) {
        var keep: [ActiveEvent] = []
        for var e in s.events {
            if e.startsDay > s.day { keep.append(e); continue }
            if e.startsDay == s.day, e.title == "Tip" {
                applyShock(&s, city: e.city, good: e.good, pct: e.pct)
            } else {
                let m = 1 + Double(e.pct) / 100 * 0.5
                s.markets[e.city].price[e.good] = max(1, Int(Double(s.markets[e.city].price[e.good]) * m))
            }
            e.daysLeft -= 1
            if e.daysLeft > 0 { keep.append(e) }
        }
        s.events = Array(keep.suffix(16))
    }

    static func applyStory(_ s: inout GameState, _ story: Story, lines: inout [String]) {
        switch story.kind {
        case .shortage:
            s.markets[story.city].price[story.good] = Int(Double(s.markets[story.city].price[story.good]) * s.rng.uniform(1.6, 2.4))
            s.markets[story.city].supply[story.good] = Int(Double(s.markets[story.city].supply[story.good]) * 0.35)
        case .collapse:
            s.markets[story.city].price[story.good] = max(1, Int(Double(s.markets[story.city].price[story.good]) * s.rng.uniform(0.3, 0.6)))
            s.markets[story.city].supply[story.good] += s.rng.int(100, 400)
        case .crackdown:
            if story.city == s.city {
                s.heat = min(100, s.heat + s.rng.int(8, 20))
                lines.append("There are more uniforms on the street than usual.")
            }
        }
    }

    static func friendGift(_ s: inout GameState, lines: inout [String]) {
        let good = s.rng.int(0, Catalog.goods.count - 1)
        let qty = min(s.rng.int(2, 15), space(s))
        guard qty > 0 else { return }
        s.carry[good] += qty
        let text = Press.friendGifts[s.rng.int(0, Press.friendGifts.count - 1)]
        lines.append(Press.fill(text, city: "", good: Catalog.goods[good].name).replacingOccurrences(of: "{qty}", with: "\(qty)"))
    }

    // MARK: Rank and the end

    static func updateRank(_ s: inout GameState) {
        let target = Catalog.rank(for: netWorth(s))
        if target < s.rankIndex {
            s.rankIndex = target; s.rankPending = target; s.rankDays = 0
        } else if target > s.rankIndex {
            if s.rankPending != target { s.rankPending = target; s.rankDays = 0 }
            s.rankDays += 1
            if s.rankDays >= 3 { s.rankIndex = target; s.rankDays = 0 }
        } else {
            s.rankPending = target; s.rankDays = 0
        }
    }

    static func checkEnd(_ s: inout GameState) {
        if s.health <= 0 {
            s.health = 0
            s.encounters = []
            s.over = GameOver(worth: netWorth(s), rank: s.rankIndex, died: true,
                              epitaph: Press.deaths[s.rng.int(0, Press.deaths.count - 1)])
        } else if s.day > s.maxDay, s.encounters.isEmpty {
            s.day = s.maxDay
            let worth = netWorth(s)
            s.over = GameOver(worth: worth, rank: Catalog.rank(for: worth), died: false, epitaph: epitaph(worth))
        }
    }

    static func epitaph(_ worth: Int) -> String {
        switch worth {
        case ..<0: "You leave town owing more than you came with. Somebody will be along to discuss it."
        case ..<10_000: "Thirty days, a lot of trains, and not much to show for it. There are worse endings."
        case ..<100_000: "Enough for a deposit on a flat and a lifetime of looking over your shoulder."
        case ..<1_000_000: "The papers call you a ‘businessman’. They put the quotation marks in themselves."
        case ..<10_000_000: "A millionaire. Nobody can prove a thing, and nobody is brave enough to try."
        default: "They’ll be telling stories about you in every lock-up from Cork to Aberdeen."
        }
    }
}
