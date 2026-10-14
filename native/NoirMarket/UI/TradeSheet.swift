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
                    Image(systemName: g.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Noir.ink)
                        .frame(width: 52, height: 52)
                        .background(Noir.paper, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(Noir.display(30)).foregroundStyle(Noir.paper)
                        Text("\(Money.gbp(price)) each · \(s.markets[s.city].supply[good]) about")
                            .font(Noir.mono(12, weight: .regular)).foregroundStyle(Noir.silver)
                    }
                    Spacer()
                }

                Picker("", selection: $selling) {
                    Text("Buy").tag(false)
                    Text("Sell").tag(true)
                }
                .pickerStyle(.segmented)
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
                            .tint(Noir.neon)
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
                        let ok = store.act { st in
                            if selling { try Engine.sell(&st, good: good, qty: q) } else { try Engine.buy(&st, good: good, qty: q) }
                        }
                        if ok {
                            Audio.shared.buzz(.success)
                            if selling { Audio.shared.play(.cash) }
                            dismiss()
                        }
                    }
                    .buttonStyle(selling ? NoirButtonStyle(kind: .secondary) : NoirButtonStyle(kind: .primary))
                    .accessibilityIdentifier("tradeAction")
                    .disabled(q == 0)
                    .opacity(q == 0 ? 0.4 : 1)
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
            .background(Noir.smoke, in: RoundedRectangle(cornerRadius: 3))
    }
}
