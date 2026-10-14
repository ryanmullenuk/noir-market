import SwiftUI

struct TravelView: View {
    var onDone: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @State private var selected: Int?
    @State private var shipMode = false
    @State private var shipQty: [Int] = Array(repeating: 0, count: Catalog.goods.count)
    @State private var preflight: Int?

    var body: some View {
        if let s = store.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SheetTitle(kicker: shipMode ? "Overnight, to the depot" : "Every trip takes a night", title: shipMode ? "Ship Ahead" : "Travel")

                    HStack(spacing: 6) {
                        modeButton("Travel", active: !shipMode) { shipMode = false }
                        modeButton("Ship ahead", active: shipMode) { shipMode = true }
                    }
                    .padding(4)
                    .background(Capsule().fill(Color.white.opacity(0.05)))

                    MapView(s: s, selected: $selected)
                        .frame(height: 330)
                        .background(RadialGradient(colors: [Noir.green.opacity(0.06), .clear], center: .center, startRadius: 10, endRadius: 260))
                        .card(padding: 0)
                        .clipShape(RoundedRectangle(cornerRadius: Noir.radius, style: .continuous))

                    if shipMode {
                        ShipForm(s: s, dest: selected, qty: $shipQty, onSent: {
                            shipQty = Array(repeating: 0, count: Catalog.goods.count)
                            Audio.shared.play(.click)
                        })
                    } else if let dest = selected {
                        DestinationCard(s: s, dest: dest, onGo: { go(dest) })
                    } else {
                        Text("Tap a city on the map or pick one below.").font(Noir.type(13)).foregroundStyle(Noir.dim)
                    }

                    VStack(spacing: 0) {
                        ForEach(Catalog.cities.filter { $0.id != s.city }.sorted { Engine.fare(s, to: $0.id) < Engine.fare(s, to: $1.id) }) { c in
                            let open = Engine.accessible(s, c.id)
                            Button {
                                selected = c.id
                                Audio.shared.buzz(.tap)
                            } label: {
                                HStack {
                                    if !open { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Noir.brass) }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name.uppercased()).font(Noir.ui(15, weight: .semibold)).foregroundStyle(open ? Noir.paper : Noir.dim)
                                        Text(c.region).font(Noir.ui(10)).foregroundStyle(Noir.dim)
                                    }
                                    Spacer()
                                    Image(systemName: Catalog.cities[s.city].needsFlight(to: c) ? "airplane" : "tram.fill")
                                        .font(.system(size: 11)).foregroundStyle(Noir.dim)
                                    Text(open ? Money.gbp(Engine.fare(s, to: c.id)) : "Full game")
                                        .font(Noir.mono(13)).foregroundStyle(open ? Noir.silver : Noir.brass)
                                        .frame(width: 84, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(selected == c.id ? Noir.green.opacity(0.1) : .clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Noir.rule).frame(height: 1)
                        }
                    }
                    .card(padding: 0)
                    .clipShape(RoundedRectangle(cornerRadius: Noir.radius, style: .continuous))

                    if !unlock.unlocked { UnlockCard() }
                }
                .padding(20)
            }
            .background(Noir.ink)
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ship") { shipMode = true; selected = 1 }
                #endif
            }
            .noirErrors(store)
            .noirDialog(isPresented: Binding(get: { preflight != nil }, set: { if !$0 { preflight = nil } }),
                        title: "Airport security", message: preflightMessage(s), icon: "airplane.departure", tint: Noir.amber,
                        actions: preflightActions(s))
        }
    }

    private func preflightActions(_ s: GameState) -> [DialogAction] {
        guard let dest = preflight else { return [] }
        var list: [DialogAction] = []
        if Engine.carried(s) > 0 {
            list.append(DialogAction(title: "Stash the stock, then fly", kind: .primary) {
                store.act { Engine.stashAll(&$0) }
                depart(dest)
            })
        }
        list.append(DialogAction(title: "Dump everything, then fly", kind: .danger) {
            store.act { Engine.dumpAll(&$0) }
            depart(dest)
        })
        list.append(DialogAction(title: "Risk it", kind: .amber) { depart(dest) })
        list.append(DialogAction(title: "Stay on the ground", kind: .quiet) { preflight = nil })
        return list
    }

    private func preflightMessage(_ s: GameState) -> String {
        var parts: [String] = []
        if Engine.carried(s) > 0 { parts.append("\(Engine.carried(s)) units of stock") }
        if Engine.hasWeapons(s) { parts.append("weapons") }
        let room = Engine.vaultCapacity(s, s.city) - Engine.vaultUsed(s, s.city)
        return "You’re carrying \(parts.joined(separator: " and ")) through an airport. Customs will be looking. Lock-up space here: \(room) units. Weapons can’t be stashed; dump them or take your chances."
    }

    private func modeButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { action() }
            Audio.shared.buzz(.tap)
        } label: {
            Text(title)
                .font(Noir.label(12)).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(active ? Noir.amber : Noir.silver)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(active ? Noir.amber.opacity(0.15) : .clear))
                .overlay { if active { Capsule().strokeBorder(Color.white.opacity(0.8)) } }
        }
        .buttonStyle(.plain)
    }

    private func go(_ dest: Int) {
        guard let s = store.state else { return }
        let flight = Catalog.cities[s.city].needsFlight(to: Catalog.cities[dest])
        if flight && (Engine.carried(s) > 0 || Engine.hasWeapons(s)) {
            preflight = dest
            Audio.shared.buzz(.warning)
            return
        }
        depart(dest)
    }

    private func depart(_ dest: Int) {
        preflight = nil
        guard let s = store.state else { return }
        let flight = Catalog.cities[s.city].needsFlight(to: Catalog.cities[dest])
        if store.act({ try Engine.travel(&$0, to: dest) }) {
            Audio.shared.play(flight ? .bingbong : .train, volume: 0.5)
            Audio.shared.buzz(.success)
            onDone()
        }
    }
}

/// Pick a destination on the map, choose what to send, pay, and it waits at that city's depot.
private struct ShipForm: View {
    let s: GameState
    let dest: Int?
    @Binding var qty: [Int]
    var onSent: () -> Void
    @Environment(GameStore.self) private var store

    var body: some View {
        let available = Catalog.goods.filter { s.carry[$0.id] + s.vault[s.city][$0.id] > 0 }
        VStack(alignment: .leading, spacing: 12) {
            if let dest, Engine.accessible(s, dest) {
                Text("To \(Catalog.cities[dest].name.uppercased())").font(Noir.display(24)).foregroundStyle(Noir.green)
            } else {
                Text("Pick a destination on the map.").font(Noir.ui(13)).foregroundStyle(Noir.dim)
            }
            if available.isEmpty {
                Text("Nothing to send. Stock in your bag or this city’s lock-up can be shipped.").font(Noir.ui(13)).foregroundStyle(Noir.silver)
            }
            ForEach(available) { g in
                let have = s.carry[g.id] + s.vault[s.city][g.id]
                HStack(spacing: 10) {
                    SymbolImage(name: g.symbol, size: 15).foregroundStyle(Noir.silver).frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(g.name).font(Noir.ui(14, weight: .semibold)).foregroundStyle(Noir.paper)
                        Text("\(have) available").font(Noir.ui(10)).foregroundStyle(Noir.dim)
                    }
                    Spacer()
                    let step = max(1, have / 10)
                    HStack(spacing: 8) {
                        Button { qty[g.id] = max(0, qty[g.id] - step) } label: { Image(systemName: "minus").font(.system(size: 12, weight: .bold)) }
                            .buttonStyle(.plain).foregroundStyle(Noir.amber).frame(width: 28, height: 28)
                        Text("\(qty[g.id])").font(Noir.mono(15)).foregroundStyle(qty[g.id] > 0 ? Noir.amber : Noir.dim).frame(minWidth: 34)
                        Button { qty[g.id] = min(have, qty[g.id] + step) } label: { Image(systemName: "plus").font(.system(size: 12, weight: .bold)) }
                            .buttonStyle(.plain).foregroundStyle(Noir.amber).frame(width: 28, height: 28)
                    }
                    Button("All") { qty[g.id] = have }
                        .font(Noir.label(10)).foregroundStyle(Noir.amber)
                        .buttonStyle(.plain)
                }
            }
            if let dest, Engine.accessible(s, dest), qty.reduce(0, +) > 0 {
                let cost = Engine.shippingCost(s, goods: qty, to: dest)
                let risk = Int((Engine.interceptionRisk(s, to: dest) * 100).rounded())
                Text("Cost \(Money.gbp(cost)) · about \(risk)% chance something goes wrong: skimmed, stolen by a rival crew, or police waiting at the depot.")
                    .font(Noir.ui(12)).foregroundStyle(risk > 25 ? Noir.red : risk > 12 ? Noir.amber : Noir.silver)
                Button("Send \(qty.reduce(0, +)) units") {
                    if store.act({ try Engine.ship(&$0, goods: qty, to: dest) }) { onSent() }
                }
                .buttonStyle(.noirAmber)
            }
        }
        .card(tint: Noir.amber)
    }
}

private struct DestinationCard: View {
    let s: GameState
    let dest: Int
    var onGo: () -> Void
    @Environment(Unlock.self) private var unlock

    var body: some View {
        let c = Catalog.cities[dest]
        let open = Engine.accessible(s, dest)
        let flight = Catalog.cities[s.city].needsFlight(to: c)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(c.name.uppercased()).font(Noir.display(28)).foregroundStyle(Noir.green)
                Spacer()
                if open { Text(Money.gbp(Engine.fare(s, to: dest))).font(Noir.mono(18)).foregroundStyle(Noir.paper) }
            }
            Text("Goes cheap: " + c.cheap.map { Catalog.goods[$0].name }.joined(separator: ", "))
                .font(Noir.type(13)).foregroundStyle(Noir.silver)
            Text("Sells dear: " + c.dear.map { Catalog.goods[$0].name }.joined(separator: ", "))
                .font(Noir.type(13)).foregroundStyle(Noir.brass)
            if flight && (Engine.carried(s) > 0 || Engine.hasWeapons(s)) {
                Label("A flight means customs. Carrying makes a stop much more likely\(Engine.hasWeapons(s) ? ", and weapons more so" : "").", systemImage: "exclamationmark.triangle.fill")
                    .font(Noir.type(12)).foregroundStyle(Noir.neon)
            }
            if open {
                Button(flight ? "Fly to \(c.name)" : "Go to \(c.name)", action: onGo).buttonStyle(.noirPrimary)
            } else {
                Button(unlock.busy ? "…" : "Unlock all cities") { Task { await unlock.purchase() } }
                    .buttonStyle(.noirAmber)
            }
        }
        .card()
    }
}

/// A hand-traced outline of Great Britain and Ireland with the 14 cities on it.
struct MapView: View {
    let s: GameState
    @Binding var selected: Int?

    static let britain: [(Double, Double)] = [
        (1.3, 51.13), (1.42, 51.36), (0.6, 51.5), (1.3, 51.85), (1.73, 52.3), (1.7, 52.75), (1.3, 52.95), (0.3, 52.9),
        (0.35, 53.3), (0.1, 53.6), (-0.2, 54.1), (-0.6, 54.5), (-1.15, 54.65), (-1.4, 55.0), (-1.6, 55.6), (-2.0, 55.8),
        (-2.5, 56.0), (-2.6, 56.3), (-2.8, 56.45), (-2.45, 56.7), (-2.05, 57.15), (-1.8, 57.5), (-2.3, 57.7), (-3.5, 57.7),
        (-4.0, 57.75), (-3.1, 58.45), (-3.0, 58.65), (-3.6, 58.6), (-5.0, 58.6), (-5.3, 58.2), (-5.6, 57.6), (-5.8, 57.3),
        (-5.7, 57.0), (-5.85, 56.75), (-6.2, 56.7), (-5.5, 56.4), (-5.6, 55.8), (-5.75, 55.3), (-4.65, 55.45), (-5.15, 54.85),
        (-4.85, 54.65), (-4.4, 54.7), (-3.5, 54.95), (-3.6, 54.5), (-3.2, 54.1), (-2.9, 54.05), (-3.05, 53.8), (-3.05, 53.45),
        (-3.3, 53.35), (-4.5, 53.4), (-4.7, 53.1), (-4.75, 52.8), (-4.1, 52.75), (-4.1, 52.4), (-4.7, 52.1), (-5.3, 51.85),
        (-5.0, 51.6), (-4.0, 51.55), (-3.15, 51.42), (-2.7, 51.55), (-3.0, 51.3), (-3.6, 51.2), (-4.2, 51.2), (-4.55, 51.0),
        (-5.0, 50.6), (-5.7, 50.05), (-5.2, 49.97), (-4.15, 50.33), (-3.65, 50.22), (-3.4, 50.6), (-2.9, 50.7), (-2.45, 50.55),
        (-1.9, 50.68), (-1.4, 50.8), (-0.8, 50.72), (-0.1, 50.8), (0.25, 50.73), (0.97, 50.92),
    ]
    static let ireland: [(Double, Double)] = [
        (-7.4, 55.38), (-6.2, 55.2), (-5.7, 54.7), (-5.45, 54.4), (-6.0, 54.0), (-6.1, 53.35), (-6.0, 52.95), (-6.35, 52.17),
        (-7.0, 52.1), (-8.3, 51.8), (-9.8, 51.45), (-10.2, 51.8), (-10.45, 52.15), (-9.9, 52.55), (-9.2, 53.15), (-10.1, 53.4),
        (-10.1, 54.0), (-9.0, 54.3), (-8.5, 54.3), (-8.7, 54.65), (-8.3, 55.15),
    ]

    var body: some View {
        GeometryReader { geo in
            let project = projection(size: geo.size)
            ZStack {
                Canvas { ctx, _ in
                    for shape in [Self.britain, Self.ireland] {
                        var p = Path()
                        for (i, pt) in shape.enumerated() {
                            let xy = project(pt.0, pt.1)
                            i == 0 ? p.move(to: xy) : p.addLine(to: xy)
                        }
                        p.closeSubpath()
                        ctx.fill(p, with: .color(Noir.smoke))
                        ctx.stroke(p, with: .color(Noir.silver.opacity(0.35)), lineWidth: 1)
                    }
                    // Route line to the selected city.
                    if let sel = selected {
                        let a = Catalog.cities[s.city], b = Catalog.cities[sel]
                        var route = Path()
                        route.move(to: project(a.lon, a.lat))
                        route.addLine(to: project(b.lon, b.lat))
                        ctx.stroke(route, with: .color(Noir.amber), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
                    }
                }
                ForEach(Catalog.cities) { c in
                    let xy = project(c.lon, c.lat)
                    let here = c.id == s.city
                    let open = Engine.accessible(s, c.id)
                    let side = Self.labelSide[c.name] ?? .below
                    ZStack {
                        marker(here: here, picked: selected == c.id, open: open)
                        Text(c.name.uppercased())
                            .font(Noir.ui(9, weight: here || selected == c.id ? .bold : .regular))
                            .foregroundStyle(here ? Noir.green : selected == c.id ? Noir.amber : open ? Noir.paper.opacity(0.85) : Noir.amber.opacity(0.55))
                            .fixedSize()
                            .frame(width: 70, alignment: side == .left ? .trailing : side == .right ? .leading : .center)
                            .offset(x: side == .left ? -41 : side == .right ? 41 : 0, y: side == .below ? 11 : side == .above ? -11 : 0)
                    }
                    .frame(width: 34, height: 34)
                    .position(xy)
                    .allowsHitTesting(false)
                    .accessibilityLabel(here ? "\(c.name), you are here" : c.name)
                    .accessibilityAction { if !here { selected = c.id } }
                }
            }
            .contentShape(Rectangle())
            // Cities in the north of England sit close together, so a tap picks the nearest one.
            .gesture(SpatialTapGesture().onEnded { tap in
                let nearest = Catalog.cities.min { a, b in
                    distance(project(a.lon, a.lat), tap.location) < distance(project(b.lon, b.lat), tap.location)
                }
                if let c = nearest, c.id != s.city, distance(project(c.lon, c.lat), tap.location) < 44 {
                    selected = c.id
                    Audio.shared.buzz(.tap)
                }
            })
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    @ViewBuilder private func marker(here: Bool, picked: Bool, open: Bool) -> some View {
        if here {
            ZStack {
                Circle().stroke(Noir.green.opacity(0.6), lineWidth: 1.5).frame(width: 18, height: 18)
                Circle().fill(Noir.green).frame(width: 9, height: 9)
            }
            .shadow(color: Noir.green, radius: 7)
        } else if picked {
            Circle().fill(Noir.amber).frame(width: 10, height: 10).shadow(color: Noir.amber, radius: 7)
        } else if open {
            Circle().fill(Noir.green.opacity(0.85)).frame(width: 6, height: 6).shadow(color: Noir.green.opacity(0.8), radius: 4)
        } else {
            Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(Noir.amber.opacity(0.7))
        }
    }

    enum Side { case left, right, above, below }
    static let labelSide: [String: Side] = [
        "Glasgow": .left, "Edinburgh": .right, "Liverpool": .above, "Manchester": .below, "Leeds": .right,
        "Cardiff": .left, "Bristol": .right, "London": .right, "Birmingham": .right, "Newcastle": .right,
        "Aberdeen": .right, "Belfast": .right, "Dublin": .left, "Cork": .left,
    ]

    private func projection(size: CGSize) -> (Double, Double) -> CGPoint {
        let minLon = -10.6, maxLon = 1.9, minLat = 49.8, maxLat = 58.8
        let k = cos(54.5 * .pi / 180)
        let w = (maxLon - minLon) * k, h = maxLat - minLat
        let scale = min((size.width - 30) / w, (size.height - 24) / h)
        let ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2
        return { lon, lat in CGPoint(x: ox + (lon - minLon) * k * scale, y: oy + (maxLat - lat) * scale) }
    }
}

struct SheetTitle: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker).noirLabel(10, color: Noir.green.opacity(0.8))
            Text(title).font(Noir.display(38)).foregroundStyle(Noir.green)
                .shadow(color: Noir.green.opacity(0.35), radius: 10)
        }
        .padding(.top, 8)
    }
}
