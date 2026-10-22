import SwiftUI

enum Panel: String, Identifiable {
    case travel, stash, money, shop, street, settings
    var id: String { rawValue }
}

struct GameView: View {
    var onQuit: () -> Void
    var onNewGame: () -> Void = {}

    @Environment(GameStore.self) private var store
    @State private var panel: Panel?
    @State private var trade: Int?
    @State private var help: StatHelp?
    @State private var note: InfoNote?

    var body: some View {
        if let s = store.state {
            ZStack {
                Noir.ink.ignoresSafeArea()
                EdgeGlow(colour: condition(s), heat: s.heat)

                VStack(spacing: 0) {
                    Header(s: s, onMenu: { panel = .settings }, onInfo: { note = $0 })
                        .padding(.horizontal, 16)
                    StatStrip(s: s, onPanel: { panel = $0 }, onHelp: { help = $0 })
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
                if panel == nil && trade == nil {
                    FlashOverlay().zIndex(9)
                }
                VStack {
                    AchievementToast()
                    Spacer()
                }
                .zIndex(7)
                .animation(.spring(duration: 0.4), value: store.toast?.id)
                if let raid = s.raid, !raid.seen, !overlayNeeded, panel == nil, trade == nil {
                    BreakingNewsView(raid: raid, onTravel: { panel = .travel })
                        .transition(.opacity)
                        .zIndex(6)
                }
                if let call = s.call, s.raid?.seen != false, !overlayNeeded, panel == nil, trade == nil {
                    IncomingCallView(call: call, city: Catalog.cities[s.city].name)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(5)
                }
            }
            .animation(.spring(duration: 0.35), value: s.call == nil)
            .animation(.easeOut(duration: 0.25), value: s.raid?.seen)
            .onAppear {
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-panel"), i + 1 < args.count { panel = Panel(rawValue: args[i + 1]) }
                if let i = args.firstIndex(of: "-trade"), i + 1 < args.count { trade = Int(args[i + 1]) }
                if let i = args.firstIndex(of: "-help"), i + 1 < args.count { help = StatHelp(rawValue: args[i + 1]) }
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
                .buttonStyle(.plain)
                .presentationDragIndicator(.visible)
                .presentationBackground(Noir.ink)
                .modifier(SheetChromeUnlessSettings(panel: p))
            }
            .onReceive(NotificationCenter.default.publisher(for: .noirSettings)) { _ in
                if trade == nil { panel = .settings }
            }
            .sheet(item: Binding(get: { trade.map(TradeID.init) }, set: { trade = $0?.id })) { t in
                TradeSheet(good: t.id)
                    .buttonStyle(.plain)
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Noir.coal)
                    .macSheet()
            }
            .coverScreen(isPresented: overlayNeeded) {
                Overlay(onQuit: {
                    onQuit()
                }, onNewGame: onNewGame)
                .buttonStyle(.plain)
            }
            .noirErrors(store, when: panel == nil && trade == nil)
            .noirDialog(isPresented: Binding(get: { help != nil }, set: { if !$0 { help = nil } }),
                        title: help.map { "\($0.title) · \($0.value(s))" } ?? "",
                        message: help?.text(s) ?? "",
                        icon: help?.symbol ?? "info.circle.fill",
                        tint: help.map { Noir.rag($0.value(s), highIsGood: $0.highIsGood) } ?? Noir.amber,
                        actions: [DialogAction(title: "Got it", kind: .secondary)])
            .noirDialog(isPresented: Binding(get: { note != nil }, set: { if !$0 { note = nil } }),
                        title: note?.title ?? "", message: note?.text ?? "",
                        icon: note?.symbol ?? "info.circle.fill", tint: note?.tint ?? Noir.amber,
                        actions: [DialogAction(title: "Got it", kind: .secondary)])
        } else {
            Color.black.onAppear { onQuit() }
        }
    }

    private var overlayNeeded: Bool {
        guard let s = store.state else { return false }
        return s.report != nil || !s.encounters.isEmpty || s.outcome != nil || s.over != nil || s.pendingEnding == true
    }

    /// The worse of health and heat, as a signal colour.
    private func condition(_ s: GameState) -> Color {
        let h = Noir.rag(s.health, highIsGood: true), t = Noir.rag(s.heat, highIsGood: false)
        if h == Noir.red || t == Noir.red { return Noir.red }
        if h == Noir.amber || t == Noir.amber { return Noir.amber }
        return Noir.green
    }

    private func stay() {
        if store.act({ try Engine.stay(&$0) }) { Audio.shared.buzz(.tap) }
    }
}

private struct TradeID: Identifiable { let id: Int }

/// A very faint glow around the edge of the screen in the player's condition colour.
private struct EdgeGlow: View {
    let colour: Color
    var heat: Int = 0
    @State private var breathe = false
    @State private var flash = 0.0
    @State private var lastHeat: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 54, style: .continuous)
            .strokeBorder(colour, lineWidth: 26)
            .blur(radius: 34)
            .opacity(colour == Noir.red ? (breathe ? 0.26 : 0.14) : 0.1)
            .overlay {
                // A heat spike flashes the edges red for a moment.
                RoundedRectangle(cornerRadius: 54, style: .continuous)
                    .strokeBorder(Noir.red, lineWidth: 34)
                    .blur(radius: 30)
                    .opacity(flash)
            }
            .ignoresSafeArea()
            .onChange(of: heat) { old, new in
                guard new - old >= 8 else { return }
                withAnimation(.easeOut(duration: 0.15)) { flash = 0.55 }
                withAnimation(.easeIn(duration: 1.1).delay(0.2)) { flash = 0 }
                Audio.shared.buzz(.warning)
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.8), value: colour)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: Header

/// A tap-to-explain note for anything in the header.
struct InfoNote: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let symbol: String
    let tint: Color
}

private struct HeaderChip: Identifiable {
    let id: String
    var symbol: String? = nil
    let text: String
    var detail: String? = nil
    let colour: Color
    let note: InfoNote
}

private struct Header: View {
    let s: GameState
    var onMenu: () -> Void
    var onInfo: (InfoNote) -> Void = { _ in }

    var body: some View {
        let left = s.maxDay - s.day
        let dayColour = left <= 2 ? Noir.red : left <= 7 ? Noir.amber : Noir.green
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .bold))
                }
                .buttonStyle(AmberTile(size: 42))
                .accessibilityLabel("Menu")

                VStack(alignment: .leading, spacing: 4) {
                    Text(Catalog.cities[s.city].name.uppercased())
                        .font(Noir.display(30))
                        .foregroundStyle(Noir.green)
                        .shadow(color: Noir.green.opacity(0.35), radius: 10)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Button { tap(weatherNote) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: weatherSymbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(weatherColour)
                            Text("\(Catalog.cities[s.city].region) · \(weatherName)")
                                .font(Noir.label(10)).tracking(1.2).textCase(.uppercase)
                                .foregroundStyle(Noir.silver)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel("\(Catalog.cities[s.city].region), \(weatherName)")
                    .accessibilityHint("Explains the weather")
                }
                Spacer(minLength: 0)

                // The month as a glowing ring.
                ZStack {
                    Circle().stroke(Color.white.opacity(0.04), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: Double(s.day) / Double(s.maxDay))
                        .stroke(dayColour, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: dayColour.opacity(0.7), radius: 6)
                    VStack(spacing: -2) {
                        Text("\(s.day)").font(Noir.mono(20)).foregroundStyle(Noir.paper)
                        Text("of \(s.maxDay)").font(Noir.ui(8, weight: .bold)).foregroundStyle(Noir.dim)
                    }
                }
                .frame(width: 56, height: 56)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day \(s.day) of \(s.maxDay)")
            }

            // Everything else as one strip of chips that scrolls sideways instead of wrapping.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips) { chip in
                        Button { tap(chip.note) } label: { chipView(chip) }
                            .buttonStyle(PressScale())
                            .accessibilityHint("Explains \(chip.text.lowercased())")
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 24)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
        }
        .padding(.top, 4)
    }

    private func tap(_ note: InfoNote) {
        Audio.shared.play(.click, volume: 0.4)
        Audio.shared.buzz(.tap)
        onInfo(note)
    }

    private func chipView(_ chip: HeaderChip) -> some View {
        HStack(spacing: 5) {
            if let symbol = chip.symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(chip.text).font(Noir.label(10)).tracking(1).textCase(.uppercase)
            if let detail = chip.detail {
                Text(detail).font(Noir.ui(9, weight: .semibold)).foregroundStyle(Noir.silver)
            }
        }
        .foregroundStyle(chip.colour)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(chip.colour.opacity(0.13)))
        .overlay(Capsule().strokeBorder(chip.colour.opacity(0.55)))
    }

    // MARK: Weather

    private var weather: String { s.weather ?? "clear" }
    private var weatherSymbol: String { weather == "rain" ? "cloud.rain.fill" : weather == "fog" ? "cloud.fog.fill" : "moon.stars.fill" }
    private var weatherColour: Color { weather == "rain" ? Noir.green : weather == "fog" ? Noir.amber : Noir.silver }
    private var weatherName: String { weather == "rain" ? "Rain" : weather == "fog" ? "Fog" : "Clear night" }
    private var weatherNote: InfoNote {
        let text = switch weather {
        case "rain": "Rain keeps the patrols in their cars. Police stops are 40% less likely tonight."
        case "fog": "Fog brings the muggers out. Street trouble is 30% more likely tonight."
        default: "A clear night. The weather isn’t helping or hurting you."
        }
        return InfoNote(title: weatherName, text: text + "\n\nThe weather changes every night, and some cities are wetter than others.", symbol: weatherSymbol, tint: weatherColour)
    }

    // MARK: Chips

    private var chips: [HeaderChip] {
        var out: [HeaderChip] = []
        let city = Catalog.cities[s.city].name

        // Rank, with progress towards the next one.
        let rank = Catalog.ranks[s.rankIndex].name
        if s.rankPending > s.rankIndex {
            let next = Catalog.ranks[s.rankPending].name
            let dots = String(repeating: "●", count: s.rankDays) + String(repeating: "○", count: max(0, 3 - s.rankDays))
            out.append(HeaderChip(id: "rank", symbol: "chevron.up.2", text: rank, detail: "\(dots) \(next)", colour: Noir.amber,
                                  note: InfoNote(title: rank, text: "Your rank follows your net worth. You’re worth enough to be a \(next): hold it for 3 days running and the street will start calling you one.\n\nSo far: \(s.rankDays) of 3 days.", symbol: "chevron.up.2", tint: Noir.amber)))
        } else {
            let nextRank = s.rankIndex + 1 < Catalog.ranks.count ? Catalog.ranks[s.rankIndex + 1] : nil
            let tail = nextRank.map { "\n\nNext: \($0.name), at a net worth of \(Money.gbp($0.threshold)), held for 3 days." } ?? "\n\nThere’s nowhere higher to go."
            out.append(HeaderChip(id: "rank", symbol: "person.fill", text: rank, colour: Noir.amber,
                                  note: InfoNote(title: rank, text: "Your rank on the street. It follows your net worth." + tail, symbol: "person.fill", tint: Noir.amber)))
        }

        // How long you've been sitting still.
        let nights = s.streak ?? 0
        if nights >= 3 {
            let colour = nights >= Engine.raidStreak ? Noir.red : Noir.amber
            out.append(HeaderChip(id: "streak", symbol: "bed.double.fill", text: "\(nights) nights here", colour: colour,
                                  note: InfoNote(title: "\(nights) nights in \(city)", text: "You’ve stayed in \(city) \(nights) nights in a row. People notice a face that doesn’t move.\n\nAfter \(Engine.raidStreak) nights a police raid gets likely. Keep moving, or keep your bag empty.", symbol: "bed.double.fill", tint: colour)))
        }

        if Engine.eventHere(s, "match") {
            out.append(HeaderChip(id: "match", symbol: "sportscourt.fill", text: "Match day", colour: Noir.red,
                                  note: InfoNote(title: "Match day", text: "The whole city’s out. Speed, coke and weed sell for about a third more today.\n\nThe police are out too: stops are 40% more likely.", symbol: "sportscourt.fill", tint: Noir.red)))
        }
        if Engine.eventHere(s, "festival") {
            out.append(HeaderChip(id: "festival", symbol: "music.note", text: "Festival", colour: Noir.amber,
                                  note: InfoNote(title: "Festival weekend", text: "Pills, acid and MDA are flying out of every tent, and their prices are up by half.", symbol: "music.note", tint: Noir.amber)))
        }

        if let crew = Catalog.rivals[s.city] {
            let t = Engine.turf(s, s.city)
            let colour = t >= 45 ? Noir.red : t >= 20 ? Noir.amber : Noir.silver
            out.append(HeaderChip(id: "turf", symbol: "flag.fill", text: "Turf \(t)%", colour: colour,
                                  note: InfoNote(title: "Turf · \(t)%", text: "This is the \(crew)’ city. Turf is how much of their attention you’ve drawn. It rises every time you sell here and fades 7 points a night.\n\nFrom 45% they may come to collect, and they won’t ask nicely.", symbol: "flag.fill", tint: colour)))
        }

        let mode = Engine.mode(s)
        if mode != .standard {
            let colour = mode == .daily ? Noir.amber : Noir.green
            out.append(HeaderChip(id: "mode", symbol: mode.symbol, text: mode.title, colour: colour,
                                  note: InfoNote(title: mode.title, text: mode.blurb, symbol: mode.symbol, tint: colour)))
        }
        if let p = Engine.perk(s) {
            out.append(HeaderChip(id: "perk", symbol: p.symbol, text: p.title, colour: Noir.silver,
                                  note: InfoNote(title: p.title, text: "+ \(p.pro)\n\n− \(p.con)", symbol: p.symbol, tint: Noir.silver)))
        }
        return out
    }
}

// MARK: Stats

private struct StatStrip: View {
    let s: GameState
    var onPanel: (Panel) -> Void = { _ in }
    var onHelp: (StatHelp) -> Void = { _ in }

    var body: some View {
        let debt = Engine.debt(s)
        let dueSoon = s.loans.contains { $0.due <= s.day + 1 }
        let fill = Double(Engine.carried(s)) / Double(max(1, Engine.capacity(s)))
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                tile("Cash", Money.short(s.cash), "sterlingsign", Noir.green, lit: true, opens: .money)
                    .animation(.spring(duration: 0.8), value: s.cash)
                tile("Bank", Money.short(s.bank), "building.columns.fill", Noir.green, lit: s.bank > 0, opens: .money)
                tile("Debt", debt > 0 ? Money.short(debt) : "None", "exclamationmark.triangle.fill", dueSoon ? Noir.red : Noir.amber, lit: debt > 0, opens: .money)
                tile("Bag", "\(Engine.carried(s))/\(Engine.capacity(s))", "bag.fill", fill >= 1 ? Noir.red : fill > 0.75 ? Noir.amber : Noir.green, lit: fill > 0, opens: .shop)
            }
            HStack(spacing: 8) {
                ForEach([StatHelp.health, .heat, .respect]) { stat in
                    Button {
                        Audio.shared.play(.click, volume: 0.4)
                        Audio.shared.buzz(.tap)
                        onHelp(stat)
                    } label: {
                        Meter(label: stat.title, symbol: stat.symbol, value: stat.value(s), colour: Noir.rag(stat.value(s), highIsGood: stat.highIsGood))
                    }
                    .buttonStyle(PressScale())
                    .accessibilityHint("Explains \(stat.title.lowercased())")
                }
            }
        }
    }

    private func tile(_ label: String, _ value: String, _ symbol: String, _ colour: Color, lit: Bool, opens: Panel) -> some View {
        Button {
            Audio.shared.buzz(.tap)
            onPanel(opens)
        } label: {
            tileBody(label, value, symbol, colour, lit: lit)
        }
        .buttonStyle(PressScale())
        .accessibilityHint(opens == .money ? "Opens Money" : "Opens Market")
    }

    private func tileBody(_ label: String, _ value: String, _ symbol: String, _ colour: Color, lit: Bool) -> some View {
        VStack(spacing: 6) {
            GlowIcon(symbol: symbol, color: colour, size: 28, lit: lit)
            Text(value).font(Noir.mono(14)).foregroundStyle(lit ? Noir.paper : Noir.silver)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label).noirLabel(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [Noir.surfaceTop, Noir.surfaceLow], startPoint: .top, endPoint: .bottom)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// Plain press feedback for tappable stat tiles.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
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
            Text("\(value)").font(Noir.mono(12)).foregroundStyle(colour).frame(width: 26, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Capsule().fill(Color.white.opacity(0.05)))
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
                    .font(Noir.ui(12, weight: .semibold))
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
                if let step = Engine.tutorialStep(s) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(step.title, systemImage: "graduationcap.fill")
                            .font(Noir.label(11)).tracking(1.2).textCase(.uppercase)
                            .foregroundStyle(Noir.green)
                        Text(step.text)
                            .font(Noir.ui(14)).foregroundStyle(Noir.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14, tint: Noir.green)
                    .shadow(color: Noir.green.opacity(0.25), radius: 12)
                    .transition(.opacity)
                }

                if s.day <= 2 && !seenTips && Engine.mode(s) != .tutorial {
                    // Compact first-day hint, so the market stays on screen.
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 13)).foregroundStyle(Noir.green)
                        (Text("Tap a drug to trade. ") + Text("CHEAP").foregroundStyle(Noir.green) + Text(" = buy here, ")
                         + Text("IN DEMAND").foregroundStyle(Noir.amber) + Text(" = sell here. Every trip or night costs a day."))
                            .font(Noir.ui(12)).foregroundStyle(Noir.paper.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            withAnimation { seenTips = true }
                        } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 16)) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Noir.dim)
                        .accessibilityLabel("Dismiss tip")
                    }
                    .card(padding: 10, tint: Noir.green)
                }

                if s.day == s.maxDay {
                    Label("Last day. No more trips. When you end the night, everything is valued at today’s prices here.", systemImage: "hourglass.bottomhalf.filled")
                        .font(Noir.ui(14, weight: .medium)).foregroundStyle(Noir.paper)
                        .card(padding: 14, tint: Noir.red)
                }

                ForEach(s.contracts ?? []) { c in
                    ContractCard(c: c, s: s, active: true)
                }

                if let crew = Catalog.rivals[s.city], Engine.turf(s, s.city) >= 30 {
                    Label("The \(crew) have noticed you selling on their streets. Move on before they come to collect.", systemImage: "flag.fill")
                        .font(Noir.ui(13, weight: .medium)).foregroundStyle(Noir.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 12, tint: Engine.turf(s, s.city) >= 45 ? Noir.red : Noir.amber)
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
                    Text("The Market").font(Noir.display(22)).foregroundStyle(Noir.green)
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
                        Text("Half of what you hear is nonsense.").font(Noir.ui(11)).foregroundStyle(Noir.dim)
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
                    Text(good.name).font(Noir.ui(16, weight: .semibold)).foregroundStyle(Noir.paper)
                    if factor < 1 { tag("cheap", Noir.green) }
                    if factor > 1 { tag("in demand", Noir.amber) }
                }
                if owned > 0 {
                    let avg = s.carryCost[good.id] / max(1, owned)
                    let pnl = (price - avg) * owned
                    Text("You hold \(owned) · \(pnl >= 0 ? "+" : "−")\(Money.short(abs(pnl)))")
                        .font(Noir.ui(11, weight: .semibold))
                        .foregroundStyle(pnl >= 0 ? Noir.green : Noir.red)
                } else {
                    Text(dry ? "Dry. Nobody’s selling." : "\(m.supply[good.id]) on the street")
                        .font(Noir.ui(11)).foregroundStyle(Noir.dim)
                }
            }
            Spacer(minLength: 4)
            if let h = s.history?[s.city][good.id], h.count > 2 {
                Sparkline(values: h).frame(width: 38, height: 18)
            }
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
            .font(Noir.ui(8, weight: .heavy)).tracking(0.8).textCase(.uppercase)
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
            HStack(spacing: 8) {
                item("Travel", "tram.fill", .travel, alert: nil).keyboardShortcut("t", modifiers: [])
                item("Stash", "shippingbox.fill", .stash, alert: stashAlert ? Noir.paper : nil).keyboardShortcut("s", modifiers: [])
                item("Money", "sterlingsign.circle.fill", .money, alert: loanAlert ? Noir.red : nil).keyboardShortcut("m", modifiers: [])
                item("Market", "bag.fill", .shop, alert: doctor ? Noir.red : nil).keyboardShortcut("k", modifiers: [])
                item("Street", "phone.fill", .street, alert: streetAlert ? Noir.green : nil).keyboardShortcut("e", modifiers: [])
            }

            Button(action: onStay) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                    Text(s.day == s.maxDay ? "Last night" : s.tradedToday ? "Stay the night" : "Lie low tonight")
                }
            }
            .buttonStyle(s.day == s.maxDay ? NoirButtonStyle(kind: .danger) : NoirButtonStyle(kind: .primary))
            .keyboardShortcut(.return, modifiers: .command)
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

    private func item(_ title: String, _ symbol: String, _ panel: Panel, alert: Color?) -> some View {
        Button {
            Audio.shared.buzz(.tap)
            onSelect(panel)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                Text(title).font(Noir.label(8)).tracking(0.6).textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AmberTile(height: 52))
        .overlay(alignment: .topTrailing) {
            if let alert {
                Circle().fill(alert).frame(width: 9, height: 9)
                    .shadow(color: alert, radius: 5)
                    .offset(x: -6, y: 6)
            }
        }
        .accessibilityIdentifier("dock-\(panel.rawValue)")
    }
}

/// Dock and menu tile: crisp white ring, amber icon, barely any fill.
struct AmberTile: ButtonStyle {
    var size: CGFloat? = nil
    var height: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        configuration.label
            .foregroundStyle(Noir.amber)
            .frame(width: size, height: size ?? height)
            .frame(maxWidth: size == nil ? .infinity : nil)
            .background(shape.fill(Noir.amber.opacity(configuration.isPressed ? 0.14 : 0.03)))
            .overlay(shape.strokeBorder(Color.white.opacity(configuration.isPressed ? 1 : 0.8), lineWidth: 1.2))
            .shadow(color: Noir.amber.opacity(configuration.isPressed ? 0.5 : 0), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}


/// Settings has its own close button; every other game panel gets the Mac sheet chrome.
private struct SheetChromeUnlessSettings: ViewModifier {
    let panel: Panel
    @ViewBuilder func body(content: Content) -> some View {
        if panel == .settings { content.macSheetSize() } else { content.macSheet() }
    }
}
