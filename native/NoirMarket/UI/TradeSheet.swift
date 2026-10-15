import SwiftUI

struct TradeSheet: View {
    let good: Int
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selling = false
    @State private var qty: Double = 0

    var body: some View {
        if let s = store.state {
            let g = Catalog.goods[good]
            let price = s.markets[s.city].price[good]
            let owned = s.carry[good]
            let maxQty = selling ? owned : Engine.maxBuy(s, good: good)
            let q = min(Int(qty), maxQty)
            let quote = q == 0 ? 0 : selling ? Engine.sellQuote(s, good: good, qty: q) : Engine.buyQuote(s, good: good, qty: q)
            let avg = owned > 0 ? s.carryCost[good] / owned : 0

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    GlowIcon(symbol: g.symbol, color: selling ? Noir.red : Noir.green, size: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(Noir.display(30)).foregroundStyle(Noir.paper)
                        Text("\(Money.gbp(price)) each · \(s.markets[s.city].supply[good]) about")
                            .font(Noir.mono(12, weight: .regular)).foregroundStyle(Noir.silver)
                    }
                    Spacer()
                }

                HStack(spacing: 6) {
                    segment("Buy", active: !selling, colour: Noir.green) { selling = false }
                    segment("Sell", active: selling, colour: Noir.red) { selling = true }
                }
                .padding(4)
                .background(Capsule().fill(Color.white.opacity(0.05)))
                .onChange(of: selling) { qty = selling ? Double(owned) : 0 }

                if maxQty == 0 {
                    Text(reason(s, owned: owned))
                        .font(Noir.type(14)).foregroundStyle(Noir.silver)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(q)").font(Noir.display(52)).foregroundStyle(Noir.paper)
                                .contentTransition(.numericText())
                            Text("units").noirLabel()
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(selling ? "You get" : "You pay").noirLabel(9)
                                Text(Money.gbp(quote)).font(Noir.mono(22)).foregroundStyle(selling ? Noir.rise : Noir.paper)
                                    .contentTransition(.numericText())
                            }
                        }
                        Slider(value: $qty, in: 0...Double(max(1, maxQty)), step: 1)
                            .tint(selling ? Noir.red : Noir.green)
                        HStack(spacing: 8) {
                            chip("None") { qty = 0 }
                            chip("Half") { qty = Double(maxQty / 2) }
                            chip("Max \(maxQty)") { qty = Double(maxQty) }
                                .accessibilityIdentifier("tradeMax")
                        }
                    }

                    if q > 0 {
                        let unit = quote / q
                        VStack(alignment: .leading, spacing: 4) {
                            if unit != price {
                                Text("Moving \(q) shifts the street price: \(Money.gbp(unit)) a unit on average.")
                            }
                            if selling && owned > 0 {
                                let profit = quote - avg * q
                                Text(profit >= 0 ? "Profit on these: \(Money.gbp(profit))" : "Loss on these: \(Money.gbp(-profit))")
                                    .foregroundStyle(profit >= 0 ? Noir.rise : Noir.neon)
                            }
                            if !selling {
                                Text("Leaves you \(Money.gbp(s.cash - quote)) and \(Engine.space(s) - q) free slots.")
                            }
                        }
                        .font(Noir.type(12)).foregroundStyle(Noir.silver)
                    }

                    Button(selling ? "Sell \(q)" : "Buy \(q)") {
                        let profit = quote - avg * q
                        let ok = store.act { st in
                            if selling { try Engine.sell(&st, good: good, qty: q) } else { try Engine.buy(&st, good: good, qty: q) }
                        }
                        if ok {
                            Audio.shared.buzz(.success)
                            if selling {
                                Audio.shared.play(.cash)
                                store.flash(profit >= 0 ? "Sold at a profit" : "Sold at a loss",
                                            "\(q) \(g.name) for \(Money.gbp(quote)).", good: profit >= 0, amount: profit)
                            }
                            dismiss()
                        }
                    }
                    .buttonStyle(selling ? NoirButtonStyle(kind: .danger) : NoirButtonStyle(kind: .primary))
                    .accessibilityIdentifier("tradeAction")
                    .disabled(q == 0)
                                    }
                let elsewhere = (s.visited ?? []).filter { $0 != s.city }
                if !elsewhere.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(g.name) where you’ve been · 7 days").noirLabel(10)
                        ForEach(elsewhere, id: \.self) { c in
                            HStack(spacing: 10) {
                                Text(Catalog.cities[c].name.uppercased()).font(Noir.ui(12, weight: .semibold)).foregroundStyle(Noir.paper)
                                    .frame(width: 104, alignment: .leading)
                                let seen = Engine.remembered(s, city: c, good: good)
                                Sparkline(values: seen).frame(height: 18)
                                Text(Money.gbp(seen.last ?? 0)).font(Noir.mono(12)).foregroundStyle(Noir.silver)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                        Text("What you saw when you were last there. It will have moved since.").font(Noir.ui(10)).foregroundStyle(Noir.dim)
                    }
                    .padding(.top, 4)
                }
                if let error = store.error {
                    Text(error).font(Noir.type(12)).foregroundStyle(Noir.neon)
                }
                Spacer(minLength: 0)
            }
            .padding(22)
            .onAppear {
                selling = owned > 0 && s.markets[s.city].price[good] > avg
                qty = selling ? Double(owned) : 0
                store.error = nil
            }
        }
    }

    private func segment(_ title: String, active: Bool, colour: Color, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
            Audio.shared.buzz(.tap)
        } label: {
            Text(title)
                .font(Noir.label(13)).tracking(1.5).textCase(.uppercase)
                .foregroundStyle(active ? colour : Noir.silver)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(active ? colour.opacity(0.18) : .clear))
                .overlay(Capsule().strokeBorder(active ? colour.opacity(0.8) : .clear))
                .shadow(color: active ? colour.opacity(0.45) : .clear, radius: 8)
        }
    }

    private func reason(_ s: GameState, owned: Int) -> String {
        if selling { return "You’re not holding any \(Catalog.goods[good].name)." }
        if s.markets[s.city].supply[good] == 0 { return "Nobody in \(Catalog.cities[s.city].name) is selling today." }
        if Engine.space(s) == 0 { return "Your bag is full. Sell something, stash it, or buy a bigger bag." }
        return "You can’t afford a single unit."
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(Noir.label(11)).tracking(1.5).textCase(.uppercase)
            .foregroundStyle(Noir.silver)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Capsule().fill(Color.white.opacity(0.07)))
    }
}
