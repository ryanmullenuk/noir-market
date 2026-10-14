import SwiftUI

struct TravelView: View {
    var onDone: () -> Void
    @Environment(GameStore.self) private var store
    @Environment(Unlock.self) private var unlock
    @State private var selected: Int?

    var body: some View {
        if let s = store.state {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SheetTitle(kicker: "Every trip takes a night", title: "Travel")

                    MapView(s: s, selected: $selected)
                        .frame(height: 330)
                        .card(padding: 0)

                    if let dest = selected {
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
                                        Text(c.name).font(Noir.typeBold(15)).foregroundStyle(open ? Noir.paper : Noir.dim)
                                        Text(c.region).font(.system(size: 10)).foregroundStyle(Noir.dim)
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
                                .background(selected == c.id ? Noir.smoke : .clear)
                            }
                            Rectangle().fill(Noir.rule).frame(height: 1)
                        }
                    }
                    .card(padding: 0)

                    if !unlock.unlocked { UnlockCard() }
                }
                .padding(20)
            }
            .background(Noir.ink)
            .alert("Not so fast", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
        }
    }

    private func go(_ dest: Int) {
        if store.act({ try Engine.travel(&$0, to: dest) }) {
            Audio.shared.buzz(.success)
            onDone()
        }
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
                Text(c.name).font(Noir.display(30)).foregroundStyle(Noir.paper)
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
                    .buttonStyle(NoirButtonStyle(kind: .secondary))
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
                        ctx.stroke(route, with: .color(Noir.neon), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                ForEach(Catalog.cities) { c in
                    let xy = project(c.lon, c.lat)
                    let here = c.id == s.city
                    let open = Engine.accessible(s, c.id)
                    let side = Self.labelSide[c.name] ?? .below
                    Button {
                        if !here { selected = c.id; Audio.shared.buzz(.tap) }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(here ? Noir.neon : selected == c.id ? Noir.paper : open ? Noir.silver : Noir.dim)
                                .frame(width: here || selected == c.id ? 11 : 7)
                                .shadow(color: here ? Noir.neon : .clear, radius: 6)
                            Text(c.name)
                                .font(.system(size: 9, weight: here || selected == c.id ? .bold : .regular))
                                .foregroundStyle(here ? Noir.neon : open ? Noir.paper.opacity(0.85) : Noir.dim)
                                .fixedSize()
                                .frame(width: 70, alignment: side == .left ? .trailing : side == .right ? .leading : .center)
                                .offset(x: side == .left ? -41 : side == .right ? 41 : 0, y: side == .below ? 11 : side == .above ? -11 : 0)
                        }
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                    }
                    .position(xy)
                    .accessibilityLabel(here ? "\(c.name), you are here" : c.name)
                }
            }
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
            Text(kicker).noirLabel(10, color: Noir.neon)
            Text(title).font(Noir.display(38)).foregroundStyle(Noir.paper)
        }
        .padding(.top, 8)
    }
}
