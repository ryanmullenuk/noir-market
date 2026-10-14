import SwiftUI

/// Shared error banner used in the panels.
private struct ErrorLine: View {
    @Environment(GameStore.self) private var store
    var body: some View {
        if let e = store.error {
            Text(e).font(Noir.type(13)).foregroundStyle(Noir.neon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Noir.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Noir.red.opacity(0.5)))
                .onTapGesture { store.error = nil }
                .task { try? await Task.sleep(for: .seconds(4)); store.error = nil }
        }
    }
}

private struct Section<Content: View>: View {
    let title: String
    var note: String?
    var boxed = true
    var ring: Color? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).noirLabel(11, color: Noir.silver).padding(.leading, 4)
            if let note { Text(note).font(Noir.type(12)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4) }
            if boxed {
                VStack(alignment: .leading, spacing: 8) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14, ring: ring)
            } else {
                content
            }
        }
    }
}

private struct SmallButton: View {
    let title: String
    var enabled = true
    var tint: Color = Noir.green
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Noir.label(11)).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(enabled ? tint : Noir.dim)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(LinearGradient(colors: [(enabled ? tint : .white).opacity(enabled ? 0.2 : 0.05), (enabled ? tint : .white).opacity(0.04)], startPoint: .top, endPoint: .bottom)))
                .overlay { if enabled { Capsule().strokeBorder(tint.opacity(0.75)) } }
                .shadow(color: enabled ? tint.opacity(0.35) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: Stash

struct StashView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let s = store.state {
            let used = Engine.vaultUsed(s, s.city), cap = Engine.vaultCapacity(s, s.city)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SheetTitle(kicker: "\(Catalog.cities[s.city].name) lock-up · \(used)/\(cap)", title: "Stash")
                    Text("Anything in a lock-up is safe from police and muggers, but it stays in this city. To move stock ahead of you, use Ship ahead on the Travel screen.")
                        .font(Noir.type(13)).foregroundStyle(Noir.silver)
                    ErrorLine()

                    let here = s.shipments.filter { $0.to == s.city && $0.landed == true }
                    if !here.isEmpty {
                        Section(title: "At the depot", note: "Shipments wait here until you collect them. They go into your bag first, then the lock-up.") {
                            ForEach(here) { sh in
                                HStack(spacing: 12) {
                                    GlowIcon(symbol: "shippingbox.fill", color: Noir.amber, size: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("From \(Catalog.cities[sh.from].name.uppercased())").font(Noir.ui(14, weight: .semibold)).foregroundStyle(Noir.paper)
                                        Text(Catalog.goods.indices.filter { sh.goods[$0] > 0 }.map { "\(sh.goods[$0]) \(Catalog.goods[$0].name)" }.joined(separator: ", "))
                                            .font(Noir.ui(11)).foregroundStyle(Noir.silver)
                                    }
                                    Spacer()
                                    SmallButton(title: "Collect", tint: Noir.amber) {
                                        if store.act({ try Engine.collect(&$0, shipment: sh.id) }) { Audio.shared.buzz(.success) }
                                    }
                                }
                            }
                        }
                    }

                    Section(title: "On you") {
                        let held = Catalog.goods.filter { s.carry[$0.id] > 0 }
                        if held.isEmpty { Text("Empty pockets.").font(Noir.type(13)).foregroundStyle(Noir.dim) }
                        ForEach(held) { g in
                            row(g, qty: s.carry[g.id]) {
                                SmallButton(title: "Stash all") { store.act { try Engine.stash(&$0, good: g.id, qty: min($0.carry[g.id], cap - Engine.vaultUsed($0, $0.city))) } }
                            }
                        }
                    }

                    Section(title: "In the lock-up") {
                        let held = Catalog.goods.filter { s.vault[s.city][$0.id] > 0 }
                        if held.isEmpty { Text("Just a mattress and a smell.").font(Noir.type(13)).foregroundStyle(Noir.dim) }
                        ForEach(held) { g in
                            row(g, qty: s.vault[s.city][g.id]) {
                                SmallButton(title: "Take", tint: Noir.paper) { store.act { try Engine.retrieve(&$0, good: g.id, qty: min($0.vault[$0.city][g.id], Engine.space($0))) } }
                            }
                        }
                    }

                    if s.vaultLevel[s.city] + 1 < Catalog.vaultLevels.count {
                        let next = Catalog.vaultLevels[s.vaultLevel[s.city] + 1]
                        Section(title: "Upgrade", note: "\(next.name) lock-up holds \(next.capacity) units.") {
                            Button("Upgrade for \(Money.gbp(next.cost))") { store.act { try Engine.upgradeVault(&$0) } }
                                .buttonStyle(.noir)
                        }
                    }

                    let elsewhere = Catalog.cities.filter { $0.id != s.city && Engine.vaultUsed(s, $0.id) > 0 }
                    let inbound = s.shipments.filter { $0.to != s.city || $0.landed != true }
                    if !elsewhere.isEmpty || !inbound.isEmpty {
                        Section(title: "Elsewhere") {
                            ForEach(elsewhere) { c in
                                Text("\(c.name): \(Engine.vaultUsed(s, c.id)) units").font(Noir.type(13)).foregroundStyle(Noir.silver)
                            }
                            ForEach(inbound) { sh in
                                Text("\(sh.landed == true ? "Waiting at the depot in" : "On the road to") \(Catalog.cities[sh.to].name): \(sh.goods.reduce(0, +)) units").font(Noir.type(13)).foregroundStyle(Noir.brass)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Noir.ink)
        }
    }

    private func row<Trailing: View>(_ g: Good, qty: Int, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            SymbolImage(name: g.symbol, size: 16).foregroundStyle(Noir.silver).frame(width: 24)
            Text(g.name).font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.paper)
            Text("×\(qty)").font(Noir.mono(13)).foregroundStyle(Noir.silver)
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }
}

// MARK: Money

struct MoneyView: View {
    @Environment(GameStore.self) private var store
    @State private var quip: Quip?
    @State private var amount = ""
    @State private var borrowing: Lender?
    @State private var borrowAmount: Double = 0

    var body: some View {
        if let s = store.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SheetTitle(kicker: "Clean money, dirty money", title: "Money")
                    HStack(spacing: 0) {
                        figure("Cash", s.cash, Noir.paper)
                        figure("Bank", s.bank, Noir.silver)
                        figure("Owed", Engine.debt(s), Engine.debt(s) > 0 ? Noir.neon : Noir.dim)
                    }
                    .card()
                    ErrorLine()

                    Section(title: "The bank", note: "Money in the bank can’t be stolen or seized. No interest, no questions.", ring: .white.opacity(0.75)) {
                        TextField("", text: $amount, prompt: Text("Amount").foregroundStyle(Noir.dim))
                            .keyboardType(.numberPad)
                            .font(Noir.mono(18))
                            .foregroundStyle(Noir.paper)
                            .padding(12)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.32)))
                        HStack(spacing: 8) {
                            Button("Deposit") { bank(true, s) }.buttonStyle(.noirOutline)
                            Button("Withdraw") { bank(false, s) }.buttonStyle(.noirOutline)
                        }
                        HStack(spacing: 8) {
                            Button("Bank it all") { store.act { try Engine.deposit(&$0, $0.cash) } }.buttonStyle(.noirOutline)
                            Button("Take it all") { store.act { try Engine.withdraw(&$0, $0.bank) } }.buttonStyle(.noirOutline)
                        }
                    }

                    if !s.loans.isEmpty {
                        Section(title: "What you owe", boxed: false) {
                            ForEach(s.loans) { loan in
                                let owed = Engine.payoff(loan, day: s.day)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(Catalog.lenders[loan.lender].name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                                        Spacer()
                                        Text(Money.gbp(owed)).font(Noir.mono(16)).foregroundStyle(Noir.neon)
                                    }
                                    Text(loan.due > s.day ? "Due day \(loan.due). Paying early saves interest." : loan.due == s.day ? "Due today." : "Overdue.")
                                        .font(Noir.type(12)).foregroundStyle(loan.due <= s.day ? Noir.neon : Noir.dim)
                                    HStack(spacing: 8) {
                                        SmallButton(title: "Pay in full", enabled: s.cash >= owed) { store.act { try Engine.repay(&$0, loan: loan.id, amount: owed) } }
                                        if let a = Int(amount), a > 0, a < owed {
                                            SmallButton(title: "Pay \(Money.gbp(a))", enabled: s.cash >= a) { store.act { try Engine.repay(&$0, loan: loan.id, amount: a) } }
                                        }
                                    }
                                }
                                .card()
                            }
                        }
                    }

                    let dirty = Engine.dirty(s), wash = Engine.launderCapacity(s)
                    Section(title: "Fronts", note: "Legit businesses earn a little each night and wash dirty cash. Over \(Money.short(Catalog.dirtyLimit)) of unwashed money draws police heat every night.", boxed: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Dirty cash").noirLabel(10)
                                Spacer()
                                Text(Money.gbp(dirty)).font(Noir.mono(15)).foregroundStyle(dirty > Catalog.dirtyLimit ? Noir.red : dirty > Catalog.dirtyLimit / 2 ? Noir.amber : Noir.green)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    let c = dirty > Catalog.dirtyLimit ? Noir.red : dirty > Catalog.dirtyLimit / 2 ? Noir.amber : Noir.green
                                    Capsule().fill(c).frame(width: max(6, geo.size.width * min(1, Double(dirty) / Double(Catalog.dirtyLimit * 2))))
                                        .shadow(color: c.opacity(0.7), radius: 5)
                                    Rectangle().fill(Color.white.opacity(0.6)).frame(width: 1.5).offset(x: geo.size.width / 2)
                                }
                            }
                            .frame(height: 6)
                            Text(wash > 0 ? "Your fronts wash \(Money.gbp(wash)) a night." : "Nothing washing it. Every sale adds to the pile.")
                                .font(Noir.ui(11)).foregroundStyle(Noir.silver)
                        }
                        .card(padding: 14, ring: .white.opacity(0.75))
                        ForEach(Catalog.businesses) { b in
                            let owned = (s.businesses ?? []).contains(b.id)
                            HStack(alignment: .top, spacing: 12) {
                                GlowIcon(symbol: b.symbol, color: Noir.amber, size: 38, lit: owned)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(b.name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                                    Text("+\(Money.gbp(b.income)) a night · washes \(Money.short(b.launders))").font(Noir.mono(11, weight: .regular)).foregroundStyle(Noir.amber)
                                    Text(b.blurb).font(Noir.ui(12)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                if owned {
                                    Text("Owned").noirLabel(10, color: Noir.amber)
                                } else {
                                    SmallButton(title: Money.short(b.price), enabled: s.cash >= b.price, tint: Noir.amber) {
                                        if store.act({ try Engine.buyBusiness(&$0, b.id) }) { Audio.shared.play(.cash, volume: 0.5) }
                                    }
                                }
                            }
                            .card(padding: 14, tint: owned ? Noir.amber : nil)
                        }
                    }

                    Section(title: "Lenders", note: "One loan per lender. Miss a payment and the debt jumps 20%, then they come looking.", boxed: false) {
                        ForEach(Catalog.lenders) { l in
                            let has = s.loans.contains { $0.lender == l.id }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(l.name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                                    Spacer()
                                    Text("up to \(Money.short(Engine.lenderLimit(s, l)))").font(Noir.mono(12)).foregroundStyle(Noir.silver)
                                }
                                Text("\(Int(l.rate * 100))% over \(l.term) days").font(Noir.mono(11, weight: .regular)).foregroundStyle(Noir.brass)
                                Text(l.bio).font(Noir.type(12)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true)
                                SmallButton(title: has ? "Already in debt to him" : "Borrow", enabled: !has) {
                                    borrowing = l
                                    borrowAmount = Double(Engine.lenderLimit(s, l) / 2)
                                }
                            }
                            .card()
                        }
                    }
                }
                .padding(20)
            }
            .background(Noir.ink)
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .top) { QuipBanner(quip: $quip) }
            .sheet(item: $borrowing) { l in
                let limit = Engine.lenderLimit(s, l)
                VStack(alignment: .leading, spacing: 16) {
                    SheetTitle(kicker: "\(Int(l.rate * 100))% over \(l.term) days", title: l.name)
                    Text(Money.gbp(Int(borrowAmount))).font(Noir.display(44)).foregroundStyle(Noir.paper)
                    Slider(value: $borrowAmount, in: 500...Double(limit), step: 500).tint(Noir.neon)
                    Text("Repay \(Money.gbp(Int(borrowAmount * (1 + l.rate)))) by day \(s.day + l.term) at the latest.")
                        .font(Noir.type(13)).foregroundStyle(Noir.silver)
                    Button("Shake on it") {
                        var line = ""
                        let amount = Int(borrowAmount)
                        if store.act({ try Engine.borrow(&$0, lender: l.id, amount: amount); line = Engine.lenderQuip(&$0, lender: l.id, amount: amount) }) {
                            Audio.shared.buzz(.success)
                            borrowing = nil
                            quip = Quip(name: l.name, text: line)
                        }
                    }
                    .buttonStyle(.noirPrimary)
                    Spacer()
                }
                .padding(22)
                .buttonStyle(.plain)
                .presentationDetents([.medium])
                .presentationBackground(Noir.coal)
            }
        }
    }

    private func figure(_ label: String, _ value: Int, _ colour: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).noirLabel(9)
            Text(Money.short(value)).font(Noir.mono(16)).foregroundStyle(colour).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private func bank(_ deposit: Bool, _ s: GameState) {
        guard let a = Int(amount.filter(\.isNumber)), a > 0 else { store.error = "Type an amount first."; return }
        if store.act({ deposit ? try Engine.deposit(&$0, a) : try Engine.withdraw(&$0, a) }) {
            amount = ""
            Audio.shared.buzz(.success)
        }
    }
}


// MARK: Black market

struct ShopView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let s = store.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SheetTitle(kicker: "Cash only · \(Money.gbp(s.cash)) on you", title: "Black Market")
                    ErrorLine()

                    Section(title: "Carrying", note: "Bigger bags carry more. Each is a one-off purchase.") {
                        ForEach(Catalog.bags) { b in
                            let owned = s.bags.contains(b.id)
                            item(b.name, "+\(b.slots) slots", price: b.price, owned: owned ? "Owned" : nil, symbol: ["backpack.fill", "duffle.bag.fill", "car.fill", "box.truck.fill"][b.id]) {
                                store.act { try Engine.buyBag(&$0, b.id) }
                            }
                        }
                    }

                    Section(title: "The doctor", note: "No questions, no NHS number, no mercy on the bill.") {
                        ForEach([25, 50, 100], id: \.self) { pts in
                            let real = min(pts, 100 - s.health)
                            item(pts == 100 ? "Full patch-up" : "+\(pts)% health", "You’re at \(s.health)%", price: Engine.doctorPrice(s, points: max(1, real)),
                                 owned: real <= 0 ? "Healthy" : nil, symbol: "cross.case.fill", colour: Noir.rag(s.health, highIsGood: true)) {
                                store.act { try Engine.heal(&$0, points: pts) }
                            }
                        }
                    }

                    Section(title: "Burner phones", note: "One call a day to a contact with a deal. You’ve got \(s.phones).") {
                        item("Burner Phone", s.phones > 0 ? "\(s.phones) in your pocket" : "Single use", price: 500, owned: nil, symbol: "iphone.gen1", lit: s.phones > 0) { store.act { try Engine.buyPhone(&$0) } }
                    }

                    Section(title: "Hardware", note: "Better odds when it gets ugly. Every weapon draws heat, and police take them if you’re nicked.") {
                        ForEach(Catalog.weapons) { w in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(w.name).font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.paper)
                                        if s.weapons[w.id] > 0 { Text("×\(s.weapons[w.id])").font(Noir.mono(12)).foregroundStyle(Noir.brass) }
                                    }
                                    Text("\(w.note) · win \(Int(w.win * 100))% · heat +\(w.heat)").font(Noir.ui(11)).foregroundStyle(Noir.dim)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    SmallButton(title: Money.short(w.price), enabled: s.cash >= w.price) { store.act { try Engine.buyWeapon(&$0, w.id) } }
                                    if s.weapons[w.id] > 0 {
                                        SmallButton(title: "Sell \(Money.short(w.price / 2))", tint: Noir.red) { store.act { try Engine.sellWeapon(&$0, w.id) } }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
            }
            .background(Noir.ink)
        }
    }

    private func item(_ name: String, _ detail: String, price: Int, owned: String?, symbol: String = "bag.fill", colour: Color = Noir.green, lit: Bool? = nil, buy: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            GlowIcon(symbol: symbol, color: colour, size: 34, lit: lit ?? (owned != nil))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.paper)
                Text(detail).font(Noir.ui(11)).foregroundStyle(Noir.dim)
            }
            Spacer()
            if let owned {
                Text(owned).noirLabel(10, color: Noir.brass)
            } else {
                SmallButton(title: Money.short(price), enabled: (store.state?.cash ?? 0) >= price) {
                    buy()
                    Audio.shared.buzz(.success)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: Street

struct StreetView: View {
    @Environment(GameStore.self) var store
    @State private var result: Outcome?
    @State var quip: Quip?
    @State var shortfall: Int?

    var body: some View {
        if let s = store.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SheetTitle(kicker: "Who you know", title: "The Street")
                    ErrorLine()

                    if let r = result {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(r.title).font(Noir.display(26)).foregroundStyle(r.good ? Noir.paper : Noir.neon)
                            Text(r.text).font(Noir.type(14)).foregroundStyle(Noir.silver).fixedSize(horizontal: false, vertical: true)
                        }
                        .card()
                        .transition(.opacity)
                    }

                    Section(title: "Contracts", note: "Buyers who want a set amount delivered by a set day. Pays well over street price. Miss the date and your name suffers.", boxed: false) {
                        ForEach(s.contracts ?? []) { c in
                            ContractCard(c: c, s: s, active: true)
                        }
                        ForEach(s.offers ?? []) { c in
                            ContractCard(c: c, s: s, active: false)
                        }
                        if (s.contracts ?? []).isEmpty && (s.offers ?? []).isEmpty {
                            Text("No work going today. Ask again tomorrow.").font(Noir.ui(13)).foregroundStyle(Noir.dim)
                        }
                    }

                    Section(title: "Crew", note: "Paid nightly from your cash, then the bank. Miss two nights’ wages and they walk, and some of them talk.", boxed: false) {
                        ForEach(Catalog.crewRoles) { r in
                            let hired = Engine.hasCrew(s, r.id)
                            let owed = (s.crewUnpaid ?? [])[safe: r.id] ?? 0
                            HStack(alignment: .top, spacing: 12) {
                                GlowIcon(symbol: r.symbol, color: owed > 0 ? Noir.red : Noir.green, size: 38, lit: hired)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                                    Text("\(Money.gbp(r.wage)) a night" + (hired && owed > 0 ? " · \(owed) unpaid" : "")).font(Noir.mono(11, weight: .regular))
                                        .foregroundStyle(owed > 0 ? Noir.red : Noir.amber)
                                    Text(r.blurb).font(Noir.ui(12)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                if hired {
                                    SmallButton(title: "Let go", tint: Noir.red) { store.act { Engine.fire(&$0, r.id) } }
                                } else {
                                    SmallButton(title: "Hire", enabled: s.cash >= r.wage) {
                                        if store.act({ try Engine.hire(&$0, r.id) }) { Audio.shared.buzz(.success) }
                                    }
                                }
                            }
                            .card(padding: 14, tint: hired ? Noir.green : nil)
                        }
                    }

                    Section(title: "Informants", note: "Each will talk once a day. Tips are about tomorrow, and only as good as the person selling them.", boxed: false) {
                        ForEach(Catalog.informants) { info in
                            let price = s.informantPrice[info.id]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(info.name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                                    Spacer()
                                    Text(Money.gbp(price)).font(Noir.mono(14)).foregroundStyle(Noir.silver)
                                }
                                Text(info.bio).font(Noir.type(12)).foregroundStyle(Noir.dim).fixedSize(horizontal: false, vertical: true)
                                SmallButton(title: s.informantUsed[info.id] ? "Talked out for today" : "Pay up", enabled: !s.informantUsed[info.id] && s.cash >= price) {
                                    var out: Outcome?
                                    if store.act({ out = try Engine.payInformant(&$0, info.id) }) {
                                        withAnimation { result = out }
                                        Audio.shared.buzz(.tap)
                                    }
                                }
                            }
                            .card()
                        }
                    }

                    Section(title: "Contacts", note: "Burner phones: \(s.phones). One call a day. Deals settle on the spot.", boxed: false) {
                        if let deal = s.deal {
                            DealCard(deal: deal, s: s, onTake: {
                                if s.cash < deal.buyCost {
                                    // Short of cash: offer a loan, then come back to the deal.
                                    shortfall = deal.buyCost - s.cash
                                    Audio.shared.buzz(.warning)
                                    return
                                }
                                var out: Outcome?
                                if store.act({ out = try Engine.takeDeal(&$0) }) {
                                    withAnimation { result = out }
                                    Audio.shared.buzz(out?.good == true ? .success : .danger)
                                }
                            }, onHangUp: { store.act { Engine.hangUp(&$0) } })
                        } else {
                            Button(s.calledToday ? "Nobody else is picking up" : s.phones == 0 ? "Buy a burner first" : "Make a call") {
                                store.act { try Engine.callContact(&$0) }
                                withAnimation { result = nil }
                            }
                            .buttonStyle(.noir)
                            .disabled(s.calledToday || s.phones == 0)
                            .opacity(s.calledToday || s.phones == 0 ? 0.5 : 1)
                        }
                    }
                }
                .padding(20)
            }
            .background(Noir.ink)
            .overlay(alignment: .top) { QuipBanner(quip: $quip) }
            .noirDialog(isPresented: Binding(get: { shortfall != nil }, set: { if !$0 { shortfall = nil } }),
                        title: shortfall.map { "You’re \(Money.gbp($0)) short" } ?? "",
                        message: "The voice on the phone won’t wait long. Borrow the difference and the deal stays on the table.",
                        icon: "phone.fill", tint: Noir.amber, actions: shortfallActions(s))
        }
    }
}

extension StreetView {
    func shortfallActions(_ s: GameState) -> [DialogAction] {
        guard let short = shortfall else { return [] }
        let amount = max(500, Int((Double(short) / 500).rounded(.up)) * 500)
        var list = Catalog.lenders.filter { l in !s.loans.contains { $0.lender == l.id } && Engine.lenderLimit(s, l) >= amount }.map { l in
            DialogAction(title: "\(l.name): \(Money.short(amount)) · \(Int(l.rate * 100))% · \(l.term)d", kind: .amber) {
                var line = ""
                if store.act({ try Engine.borrow(&$0, lender: l.id, amount: amount); line = Engine.lenderQuip(&$0, lender: l.id, amount: amount) }) {
                    quip = Quip(name: l.name, text: line + " Now go and take that deal.")
                    Audio.shared.buzz(.success)
                }
                shortfall = nil
            }
        }
        list.append(DialogAction(title: "Never mind", kind: .quiet) { shortfall = nil })
        return list
    }
}

struct Quip: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let text: String
}

/// A lender's parting shot, dropped in from the top.
struct QuipBanner: View {
    @Binding var quip: Quip?

    var body: some View {
        if let q = quip {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(q.name) says").noirLabel(10, color: Noir.amber)
                Text(q.text).font(Noir.ui(14)).foregroundStyle(Noir.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16, tint: Noir.amber)
            .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { withAnimation { quip = nil } }
            .task(id: q.id) {
                try? await Task.sleep(for: .seconds(6))
                withAnimation { if quip?.id == q.id { quip = nil } }
            }
            .accessibilityAddTraits(.isStaticText)
        }
    }
}

private struct DealCard: View {
    let deal: DealOffer
    let s: GameState
    var onTake: () -> Void
    var onHangUp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unknown number").noirLabel(10, color: Noir.neon)
            Text("“I’ve got \(deal.qty) \(Catalog.goods[deal.good].name) and a buyer in \(Catalog.cities[deal.city].name). You front \(Money.gbp(deal.buyCost)), you get \(Money.gbp(deal.payout)) back. Tonight.”")
                .font(Noir.type(15)).foregroundStyle(Noir.paper).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                odds("Clean", deal.odds[0] + deal.odds[4])
                odds("Short", deal.odds[1])
                odds("Set-up", deal.odds[2])
                odds("Scam", deal.odds[3])
            }
            HStack(spacing: 8) {
                Button(s.cash < deal.buyCost ? "Take it (short)" : "Take it", action: onTake).buttonStyle(s.cash < deal.buyCost ? .noirAmber : .noirPrimary)
                Button("Hang up", action: onHangUp).buttonStyle(.noirQuiet)
            }
        }
        .card()
    }

    private func odds(_ label: String, _ p: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int((p * 100).rounded()))%").font(Noir.mono(14)).foregroundStyle(Noir.paper)
            Text(label).noirLabel(8)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// A delivery job: offered, or in progress with a Deliver button when you're there with the goods.
struct ContractCard: View {
    let c: Contract
    let s: GameState
    let active: Bool
    @Environment(GameStore.self) private var store

    var body: some View {
        let left = c.due - s.day
        let urgency = left <= 1 ? Noir.red : left <= 3 ? Noir.amber : Noir.green
        let ready = Engine.canDeliver(s, c)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(active ? "ACTIVE JOB" : "JOB OFFER").font(Noir.label(10)).tracking(1.4).foregroundStyle(active ? Noir.green : Noir.amber)
                Spacer()
                Text(left <= 0 ? "Due today" : "Due day \(c.due) · \(left)d").font(Noir.label(10)).foregroundStyle(urgency)
            }
            HStack(spacing: 10) {
                SymbolImage(name: Catalog.goods[c.good].symbol, size: 16).foregroundStyle(Noir.paper)
                Text("\(c.qty) \(Catalog.goods[c.good].name) → \(Catalog.cities[c.city].name.uppercased())")
                    .font(Noir.ui(15, weight: .semibold)).foregroundStyle(Noir.paper)
            }
            HStack {
                Text("Pays \(Money.gbp(c.reward))").font(Noir.mono(14)).foregroundStyle(Noir.green)
                Spacer()
                if active {
                    if ready {
                        SmallButton(title: "Deliver") {
                            if store.act({ try Engine.deliver(&$0, c.id) }) { Audio.shared.play(.cash, volume: 0.6) }
                        }
                    } else {
                        Text("You hold \(s.carry[c.good])/\(c.qty)").font(Noir.ui(11)).foregroundStyle(Noir.silver)
                    }
                } else {
                    SmallButton(title: "Take the job", enabled: (s.contracts ?? []).count < 2, tint: Noir.amber) {
                        if store.act({ try Engine.acceptContract(&$0, c.id) }) { Audio.shared.buzz(.success) }
                    }
                }
            }
        }
        .card(padding: 14, tint: active ? (ready ? Noir.green : urgency) : Noir.amber)
    }
}
