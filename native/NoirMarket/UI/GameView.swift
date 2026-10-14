import SwiftUI

enum Panel: String, Identifiable {
    case travel, stash, money, shop, street, settings
    var id: String { rawValue }
}

struct GameView: View {
    var onQuit: () -> Void

    @Environment(GameStore.self) private var store
    @State private var panel: Panel?
    @State private var trade: Int?

    var body: some View {
        if let s = store.state {
            ZStack {
                Noir.ink.ignoresSafeArea()
                Skyline(seed: UInt64(s.city) * 97 + 5, tint: Color(white: 0.045))
                    .frame(height: 190)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(0.8)
                    .ignoresSafeArea()
                LinearGradient(colors: [.clear, Noir.ink], startPoint: .top, endPoint: .init(x: 0.5, y: 0.3))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Header(s: s, onMenu: { panel = .settings })
                    StatStrip(s: s)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    Ticker(lines: s.ticker)
                        .padding(.top, 12)
                    MarketList(s: s, onTap: { trade = $0 })
                    Dock(onSelect: { panel = $0 }, onStay: { stay() }, s: s)
                }
                FilmGrain()
            }
            .onAppear {
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-panel"), i + 1 < args.count { panel = Panel(rawValue: args[i + 1]) }
                if let i = args.firstIndex(of: "-trade"), i + 1 < args.count { trade = Int(args[i + 1]) }
                #endif
            }
            .sheet(item: $panel) { p in
                Group {
                    switch p {
                    case .travel: TravelView(onDone: { panel = nil })
                    case .stash: StashView()
                    case .money: MoneyView()
                    case .shop: ShopView()
                    case .street: StreetView()
                    case .settings: SettingsView(inGame: true, onAbandon: {
                        panel = nil
                        store.abandon()
                        onQuit()
                    })
                    }
                }
                .presentationDragIndicator(.visible)
                .presentationBackground(Noir.ink)
            }
            .sheet(item: Binding(get: { trade.map(TradeID.init) }, set: { trade = $0?.id })) { t in
                TradeSheet(good: t.id)
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Noir.coal)
            }
            .fullScreenCover(isPresented: Binding(get: { overlayNeeded }, set: { _ in })) {
                Overlay(onQuit: {
                    onQuit()
                })
            }
            .alert("Not so fast", isPresented: Binding(get: { store.error != nil && panel == nil && trade == nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
        } else {
            Color.black.onAppear { onQuit() }
        }
    }

    private var overlayNeeded: Bool {
        guard let s = store.state else { return false }
        return s.report != nil || !s.encounters.isEmpty || s.outcome != nil || s.over != nil
    }

    private func stay() {
        if store.act({ try Engine.stay(&$0) }) { Audio.shared.buzz(.tap) }
    }
}

private struct TradeID: Identifiable { let id: Int }

// MARK: Header

private struct Header: View {
    let s: GameState
    var onMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Noir.silver)
                }
                .accessibilityLabel("Menu")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Day").noirLabel(10)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(s.day)").font(Noir.display(30)).foregroundStyle(s.maxDay - s.day < 3 ? Noir.neon : Noir.paper)
                        Text("/\(s.maxDay)").font(Noir.mono(12, weight: .regular)).foregroundStyle(Noir.dim)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day \(s.day) of \(s.maxDay)")
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Catalog.cities[s.city].region).noirLabel(10, color: Noir.neon)
                    Text(Catalog.cities[s.city].name)
                        .font(Noir.display(42))
                        .foregroundStyle(Noir.paper)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Catalog.ranks[s.rankIndex].name).font(Noir.typeBold(13)).foregroundStyle(Noir.brass)
                    if s.rankPending > s.rankIndex {
                        Text("\(s.rankDays)/3 to \(Catalog.ranks[s.rankPending].name)").font(.system(size: 10)).foregroundStyle(Noir.dim)
                    }
                }
            }
            // Thin progress rule for the month.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Noir.rule)
                    Rectangle().fill(Noir.neon).frame(width: geo.size.width * Double(s.day) / Double(s.maxDay))
                }
            }
            .frame(height: 2)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

// MARK: Stats

private struct StatStrip: View {
    let s: GameState

    var body: some View {
        let debt = Engine.debt(s)
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                stat("Cash", Money.short(s.cash), Noir.paper)
                divider
                stat("Bank", Money.short(s.bank), Noir.silver)
                divider
                stat("Debt", debt > 0 ? Money.short(debt) : "—", debt > 0 ? Noir.neon : Noir.dim)
                divider
                stat("Bag", "\(Engine.carried(s))/\(Engine.capacity(s))", Noir.silver)
            }
            HStack(spacing: 14) {
                Meter(label: "Health", value: s.health, colour: s.health <= 30 ? Noir.neon : Noir.paper)
                Meter(label: "Heat", value: s.heat, colour: s.heat >= 60 ? Noir.neon : s.heat >= 30 ? Noir.brass : Noir.silver)
            }
        }
        .card(padding: 12)
    }

    private var divider: some View { Rectangle().fill(Noir.rule).frame(width: 1, height: 28) }

    private func stat(_ label: String, _ value: String, _ colour: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).noirLabel(9)
            Text(value).font(Noir.mono(15)).foregroundStyle(colour).lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct Meter: View {
    let label: String
    let value: Int
    let colour: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label).noirLabel(9).lineLimit(1).fixedSize()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Noir.smoke)
                    Capsule().fill(colour).frame(width: max(2, geo.size.width * Double(value) / 100))
                        .animation(.easeOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 4)
            Text("\(value)%").font(Noir.mono(11, weight: .medium)).foregroundStyle(colour).frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) percent")
    }
}

// MARK: Ticker

struct Ticker: View {
    let lines: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0

    var body: some View {
        let text = lines.joined(separator: "   ◆   ")
        HStack(spacing: 0) {
            Text("Wire")
                .font(Noir.label(9)).tracking(2).textCase(.uppercase)
                .foregroundStyle(Noir.ink)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Noir.neon)
            GeometryReader { geo in
                Text(text)
                    .font(Noir.type(12))
                    .foregroundStyle(Noir.silver)
                    .fixedSize()
                    .background(GeometryReader { t in Color.clear.onAppear { width = t.size.width } .onChange(of: text) { width = t.size.width } })
                    .offset(x: offset)
                    .onAppear { start(container: geo.size.width) }
                    .onChange(of: text) { start(container: geo.size.width) }
            }
            .clipped()
        }
        .frame(height: 24)
        .background(Noir.coal)
        .overlay(alignment: .top) { Rectangle().fill(Noir.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Noir.rule).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("News: " + lines.joined(separator: ". "))
    }

    private func start(container: CGFloat) {
        if reduceMotion { offset = 8; return }
        offset = container
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            let distance = container + max(width, 400)
            withAnimation(.linear(duration: Double(distance) / 42).repeatForever(autoreverses: false)) {
                offset = -max(width, 400)
            }
        }
    }
}

// MARK: Market

private struct MarketList: View {
    let s: GameState
    var onTap: (Int) -> Void
    @AppStorage("seenTips") private var seenTips = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("The Market").noirLabel(11, color: Noir.silver)
                    Spacer()
                    Text(Catalog.cities[s.city].blurb[s.day % 3]).font(Noir.type(11)).foregroundStyle(Noir.dim).lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if s.day <= 2 && !seenTips {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("First night in town").noirLabel(10, color: Noir.neon)
                            Spacer()
                            Button {
                                withAnimation { seenTips = true }
                            } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                            .foregroundStyle(Noir.dim)
                            .accessibilityLabel("Dismiss tips")
                        }
                        Text("Tap anything below to buy or sell. Goods tagged CHEAP HERE are a bargain in this city; IN DEMAND means they sell high. Travel to where your stock is wanted, sell, repeat. Every trip or night’s stay moves the clock on.")
                            .font(Noir.type(13)).foregroundStyle(Noir.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Noir.neon.opacity(0.5)))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                if s.day == s.maxDay {
                    Text("Last day. No more trips. When you call it a night, everything you own is valued at today’s prices here, and the case closes.")
                        .font(Noir.type(13)).foregroundStyle(Noir.neon)
                        .padding(.horizontal, 16).padding(.bottom, 8)
                }

                if !s.notice.isEmpty {
                    Text(s.notice)
                        .font(Noir.type(13))
                        .foregroundStyle(Noir.paper.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Noir.smoke.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                ForEach(Catalog.goods) { g in
                    MarketRow(s: s, good: g)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Audio.shared.buzz(.tap)
                            onTap(g.id)
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("good-\(g.name)")
                    Rectangle().fill(Noir.rule.opacity(0.6)).frame(height: 1).padding(.leading, 60)
                }

                if let story = s.story {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Word on the street").noirLabel(10, color: Noir.brass)
                        Text(story.text).font(Noir.type(13)).foregroundStyle(Noir.silver)
                        Text("Half of what you hear is nonsense.").font(.system(size: 10)).foregroundStyle(Noir.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MarketRow: View {
    let s: GameState
    let good: Good

    var body: some View {
        let m = s.markets[s.city]
        let price = m.price[good.id]
        let prev = m.previous[good.id]
        let change = prev > 0 ? Double(price - prev) / Double(prev) : 0
        let owned = s.carry[good.id]
        let factor = Catalog.cities[s.city].factor(for: good.id)
        let dry = m.supply[good.id] == 0

        HStack(spacing: 12) {
            Image(systemName: good.symbol)
                .font(.system(size: 15))
                .foregroundStyle(owned > 0 ? Noir.ink : Noir.silver)
                .frame(width: 34, height: 34)
                .background(owned > 0 ? Noir.paper : Noir.smoke, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(good.name).font(Noir.typeBold(16)).foregroundStyle(Noir.paper)
                    if factor < 1 { tag("cheap here", Noir.silver) }
                    if factor > 1 { tag("in demand", Noir.brass) }
                }
                if owned > 0 {
                    let avg = s.carryCost[good.id] / max(1, owned)
                    let up = price >= avg
                    Text("Holding \(owned) · paid \(Money.gbp(avg)) avg")
                        .font(.system(size: 11))
                        .foregroundStyle(up ? Noir.rise : Noir.neon)
                } else {
                    Text(dry ? "Dry. Nobody’s selling." : "\(m.supply[good.id]) on the street")
                        .font(.system(size: 11)).foregroundStyle(Noir.dim)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.gbp(price)).font(Noir.mono(16)).foregroundStyle(Noir.paper)
                    .contentTransition(.numericText())
                if abs(change) >= 0.005 {
                    Text("\(change > 0 ? "▲" : "▼") \(Int((abs(change) * 100).rounded()))%")
                        .font(Noir.mono(10, weight: .medium))
                        .foregroundStyle(change > 0 ? Noir.rise : Noir.neon)
                } else {
                    Text("steady").font(Noir.mono(10, weight: .regular)).foregroundStyle(Noir.dim)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .opacity(dry && owned == 0 ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold)).tracking(1).textCase(.uppercase)
            .foregroundStyle(colour)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(colour.opacity(0.5)))
    }
}

// MARK: Dock

private struct Dock: View {
    var onSelect: (Panel) -> Void
    var onStay: () -> Void
    let s: GameState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                item("Travel", "tram.fill", .travel)
                item("Stash", "shippingbox.fill", .stash)
                item("Money", "sterlingsign", .money)
                item("Black Mkt", "bag.fill", .shop)
                item("Street", "phone.fill", .street)
            }
            Button(action: onStay) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                    Text(s.day == s.maxDay ? "Last night. End it here." : s.tradedToday ? "Stay the night" : "Lie low tonight")
                }
            }
            .buttonStyle(.noir)
            .accessibilityIdentifier("stay")
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Noir.coal.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Noir.rule).frame(height: 1) }
    }

    private func item(_ title: String, _ symbol: String, _ panel: Panel) -> some View {
        Button {
            Audio.shared.buzz(.tap)
            onSelect(panel)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(title).font(.system(size: 9, weight: .semibold)).tracking(1).textCase(.uppercase)
            }
            .foregroundStyle(Noir.silver)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("dock-\(panel.rawValue)")
    }
}
