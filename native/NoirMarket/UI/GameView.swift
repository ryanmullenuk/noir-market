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
                RadialGradient(colors: [Noir.green.opacity(0.06), .clear], center: .bottom, startRadius: 10, endRadius: 420)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Header(s: s, onMenu: { panel = .settings })
                        .padding(.horizontal, 16)
                    StatStrip(s: s)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    Ticker(lines: s.ticker)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    MarketList(s: s, onTap: { trade = $0 })
                        .padding(.top, 6)
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
        let left = s.maxDay - s.day
        let dayColour = left <= 2 ? Noir.red : left <= 7 ? Noir.amber : Noir.green
        HStack(alignment: .center, spacing: 14) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Noir.paper)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            }
            .accessibilityLabel("Menu")

            VStack(alignment: .leading, spacing: 4) {
                Text(Catalog.cities[s.city].name)
                    .font(Noir.display(36))
                    .foregroundStyle(Noir.paper)
                    .lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    Text(Catalog.cities[s.city].region)
                        .font(Noir.label(10)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(Noir.silver)
                    Text(Catalog.ranks[s.rankIndex].name)
                        .font(Noir.label(10)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(Noir.amber)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Noir.amber.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(Noir.amber.opacity(0.6)))
                        .shadow(color: Noir.amber.opacity(0.4), radius: 6)
                    if s.rankPending > s.rankIndex {
                        Text("\(s.rankDays)/3 → \(Catalog.ranks[s.rankPending].name)")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Noir.dim)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)

            // The month as a glowing ring.
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: Double(s.day) / Double(s.maxDay))
                    .stroke(dayColour, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: dayColour.opacity(0.7), radius: 6)
                VStack(spacing: -2) {
                    Text("\(s.day)").font(Noir.mono(20)).foregroundStyle(Noir.paper)
                    Text("of \(s.maxDay)").font(.system(size: 8, weight: .bold)).foregroundStyle(Noir.dim)
                }
            }
            .frame(width: 56, height: 56)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day \(s.day) of \(s.maxDay)")
        }
        .padding(.top, 4)
    }
}

// MARK: Stats

private struct StatStrip: View {
    let s: GameState

    var body: some View {
        let debt = Engine.debt(s)
        let dueSoon = s.loans.contains { $0.due <= s.day + 1 }
        let fill = Double(Engine.carried(s)) / Double(max(1, Engine.capacity(s)))
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                tile("Cash", Money.short(s.cash), "sterlingsign", Noir.green, lit: true)
                tile("Bank", Money.short(s.bank), "building.columns.fill", Noir.green, lit: s.bank > 0)
                tile("Debt", debt > 0 ? Money.short(debt) : "None", "exclamationmark.triangle.fill", dueSoon ? Noir.red : Noir.amber, lit: debt > 0)
                tile("Bag", "\(Engine.carried(s))/\(Engine.capacity(s))", "bag.fill", fill >= 1 ? Noir.red : fill > 0.75 ? Noir.amber : Noir.green, lit: fill > 0)
            }
            HStack(spacing: 10) {
                Meter(label: "Health", symbol: "heart.fill", value: s.health, colour: Noir.rag(s.health, highIsGood: true))
                Meter(label: "Heat", symbol: "flame.fill", value: s.heat, colour: Noir.rag(s.heat, highIsGood: false))
            }
        }
    }

    private func tile(_ label: String, _ value: String, _ symbol: String, _ colour: Color, lit: Bool) -> some View {
        VStack(spacing: 6) {
            GlowIcon(symbol: symbol, color: colour, size: 28, lit: lit)
            Text(value).font(Noir.mono(14)).foregroundStyle(lit ? Noir.paper : Noir.silver)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label).noirLabel(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [Color(white: 0.11), Color(white: 0.065)], startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

struct Meter: View {
    let label: String
    var symbol: String = "circle.fill"
    let value: Int
    let colour: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(colour)
                .shadow(color: colour.opacity(0.8), radius: 4)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(LinearGradient(colors: [colour.opacity(0.7), colour], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * Double(value) / 100))
                        .shadow(color: colour.opacity(0.7), radius: 5)
                        .animation(.easeOut(duration: 0.5), value: value)
                }
            }
            .frame(height: 6)
            Text("\(value)%").font(Noir.mono(12)).foregroundStyle(colour).frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
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
        let text = lines.joined(separator: "   •   ")
        HStack(spacing: 0) {
            Text("News")
                .font(Noir.label(10)).tracking(1.6).textCase(.uppercase)
                .foregroundStyle(Noir.ink)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Noir.amber))
                .shadow(color: Noir.amber.opacity(0.7), radius: 6)
                .padding(.leading, 5)
                .zIndex(1)
            GeometryReader { geo in
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Noir.paper.opacity(0.85))
                    .fixedSize()
                    .background(GeometryReader { t in Color.clear.onAppear { width = t.size.width }.onChange(of: text) { width = t.size.width } })
                    .offset(x: offset)
                    .frame(maxHeight: .infinity)
                    .onAppear { start(container: geo.size.width) }
                    .onChange(of: text) { start(container: geo.size.width) }
            }
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04), .init(color: .black, location: 0.94), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: 32)
        .background(Capsule().fill(LinearGradient(colors: [Noir.amber.opacity(0.10), Color.white.opacity(0.03)], startPoint: .leading, endPoint: .trailing)))
        .overlay(Capsule().strokeBorder(Noir.amber.opacity(0.35)))
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
            VStack(alignment: .leading, spacing: 10) {
                if s.day <= 2 && !seenTips {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("First night in town", systemImage: "lightbulb.fill")
                                .font(Noir.label(11)).tracking(1.2).textCase(.uppercase)
                                .foregroundStyle(Noir.green)
                            Spacer()
                            Button {
                                withAnimation { seenTips = true }
                            } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 17)) }
                            .foregroundStyle(Noir.dim)
                            .accessibilityLabel("Dismiss tips")
                        }
                        Text("Tap any drug to buy or sell. Green CHEAP tags are bargains in this city; gold IN DEMAND tags sell high. Carry stock to where it’s wanted, sell, repeat. Every trip or night moves the clock on.")
                            .font(Noir.ui(14)).foregroundStyle(Noir.paper.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(padding: 14, tint: Noir.green)
                }

                if s.day == s.maxDay {
                    Label("Last day. No more trips. When you end the night, everything is valued at today’s prices here.", systemImage: "hourglass.bottomhalf.filled")
                        .font(Noir.ui(14, weight: .medium)).foregroundStyle(Noir.paper)
                        .card(padding: 14, tint: Noir.red)
                }

                if !s.notice.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Noir.silver)
                        Text(s.notice)
                            .font(Noir.ui(14))
                            .foregroundStyle(Noir.paper.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .card(padding: 12)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("The Market").font(Noir.display(22)).foregroundStyle(Noir.paper)
                    Spacer()
                    Text("▲ rising").font(Noir.label(10)).foregroundStyle(Noir.green)
                    Text("▼ falling").font(Noir.label(10)).foregroundStyle(Noir.red)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)

                VStack(spacing: 0) {
                    ForEach(Catalog.goods) { g in
                        MarketRow(s: s, good: g)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Audio.shared.buzz(.tap)
                                onTap(g.id)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("good-\(g.name)")
                        if g.id < Catalog.goods.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 62)
                        }
                    }
                }
                .card(padding: 0)

                if let story = s.story {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Word on the street", systemImage: "ear.fill")
                            .font(Noir.label(10)).tracking(1.4).textCase(.uppercase)
                            .foregroundStyle(Noir.amber)
                        Text(story.text).font(Noir.type(14)).foregroundStyle(Noir.paper.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Half of what you hear is nonsense.").font(.system(size: 11)).foregroundStyle(Noir.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14, tint: Noir.amber)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
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
        let trend: Color = change >= 0.005 ? Noir.green : change <= -0.005 ? Noir.red : Noir.silver
        let big = abs(change) >= 0.15

        HStack(spacing: 12) {
            GlowIcon(symbol: good.symbol, color: owned > 0 ? Noir.paper : trend, size: 36, lit: owned > 0 || big)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(good.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Noir.paper)
                    if factor < 1 { tag("cheap", Noir.green) }
                    if factor > 1 { tag("in demand", Noir.amber) }
                }
                if owned > 0 {
                    let avg = s.carryCost[good.id] / max(1, owned)
                    let pnl = (price - avg) * owned
                    Text("You hold \(owned) · \(pnl >= 0 ? "+" : "−")\(Money.short(abs(pnl)))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(pnl >= 0 ? Noir.green : Noir.red)
                } else {
                    Text(dry ? "Dry. Nobody’s selling." : "\(m.supply[good.id]) on the street")
                        .font(.system(size: 11)).foregroundStyle(Noir.dim)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.gbp(price)).font(Noir.mono(16)).foregroundStyle(Noir.paper)
                    .contentTransition(.numericText())
                Text(abs(change) >= 0.005 ? "\(change > 0 ? "▲" : "▼") \(Int((abs(change) * 100).rounded()))%" : "steady")
                    .font(Noir.mono(10))
                    .foregroundStyle(trend)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(trend.opacity(0.14)))
                    .shadow(color: big ? trend.opacity(0.6) : .clear, radius: 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .opacity(dry && owned == 0 ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy)).tracking(0.8).textCase(.uppercase)
            .foregroundStyle(colour)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(colour.opacity(0.13)))
            .overlay(Capsule().strokeBorder(colour.opacity(0.55)))
    }
}

// MARK: Dock

private struct Dock: View {
    var onSelect: (Panel) -> Void
    var onStay: () -> Void
    let s: GameState

    var body: some View {
        let loanAlert = s.loans.contains { $0.due <= s.day + 1 }
        let stashAlert = !s.shipments.isEmpty || Engine.vaultUsed(s, s.city) > 0
        let doctor = s.health < 50
        let streetAlert = s.deal != nil
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                item("Travel", "tram.fill", .travel, glow: nil)
                item("Stash", "shippingbox.fill", .stash, glow: stashAlert ? Noir.amber : nil)
                item("Money", "sterlingsign.circle.fill", .money, glow: loanAlert ? Noir.red : nil)
                item("Market", "bag.fill", .shop, glow: doctor ? Noir.red : nil)
                item("Street", "phone.fill", .street, glow: streetAlert ? Noir.green : nil)
            }
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1)))

            Button(action: onStay) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                    Text(s.day == s.maxDay ? "End it here" : s.tradedToday ? "Stay the night" : "Lie low tonight")
                }
            }
            .buttonStyle(s.day == s.maxDay ? NoirButtonStyle(kind: .danger) : NoirButtonStyle(kind: .primary))
            .accessibilityIdentifier("stay")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            LinearGradient(colors: [Noir.ink.opacity(0), Noir.ink.opacity(0.95), Noir.ink], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ title: String, _ symbol: String, _ panel: Panel, glow: Color?) -> some View {
        Button {
            Audio.shared.buzz(.tap)
            onSelect(panel)
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(glow ?? Noir.paper.opacity(0.85))
                        .shadow(color: (glow ?? .clear).opacity(0.9), radius: 7)
                    if let glow {
                        Circle().fill(glow).frame(width: 7, height: 7)
                            .shadow(color: glow, radius: 4)
                            .offset(x: 6, y: -3)
                    }
                }
                .frame(height: 22)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Noir.silver)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .accessibilityIdentifier("dock-\(panel.rawValue)")
    }
}
