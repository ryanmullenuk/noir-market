import SwiftUI
import StoreKit

@main
struct NoirMarketApp: App {
    @State private var store = GameStore()
    @State private var unlock = Unlock()

    init() { Noir.registerFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(unlock)
                .preferredColorScheme(.dark)
                // No system glass pills on custom buttons; every styled button sets its own look.
                .buttonStyle(.plain)
                .task {
                    unlock.onChange = { [store] entitled in store.fullAccess = entitled }
                    GameCenter.authenticate()
                    // Confirm the build's environment with StoreKit; only TestFlight/Xcode builds allow test names.
                    if case .verified(let t) = try? await AppTransaction.shared {
                        GameStore.testNamesAllowed = t.environment == .sandbox || t.environment == .xcode
                        #if DEBUG
                        GameStore.testNamesAllowed = true
                        #endif
                    }
                    await unlock.start()
                }
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var screen: Screen = .title
    @State private var sheet: TitleSheet?

    enum Screen { case title, newGame, game }
    enum TitleSheet: String, Identifiable { case howTo, settings, records; var id: String { rawValue } }

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleView(hasSave: store.hasSave,
                          saveSummary: store.state.map { "Day \($0.day) · \(Catalog.cities[$0.city].name) · \(Money.gbp($0.cash))".uppercased() },
                          onContinue: { go(.game) },
                          onNewGame: { go(.newGame) },
                          onHowTo: { sheet = .howTo },
                          onSettings: { sheet = .settings },
                          onRecords: { sheet = .records })
                    .transition(.opacity)
            case .newGame:
                NewGameView(onStart: { city, mode, perk in
                    store.newGame(city: city, mode: mode, perk: perk)
                    Audio.shared.duck()
                    go(.game)
                }, onBack: { go(.title) })
                .transition(.opacity)
            case .game:
                GameView(onQuit: { go(.title) })
                    .transition(.opacity)
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .howTo: HowToPlayView().presentationBackground(Noir.ink)
            case .settings: SettingsView(inGame: false, onAbandon: {}).presentationBackground(Noir.ink)
            case .records: RecordsView().presentationBackground(Noir.ink)
            }
        }
        .onAppear(perform: debugLaunch)
        .onChange(of: phase) { _, new in
            if new == .background { store.persist() }
        }
    }

    /// DEBUG-only launch arguments for screenshots and UI checks:
    /// -demo starts a game, -days N plays N nights with default choices, -panel NAME opens a panel.
    private func debugLaunch() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-palette"), i + 1 < args.count, let p = Palette(rawValue: args[i + 1]) { Theme.shared.palette = p }
        if args.contains("-settings") { sheet = .settings }
        guard args.contains("-demo") else { return }
        let mode = args.firstIndex(of: "-mode").flatMap { i in i + 1 < args.count ? GameMode(rawValue: args[i + 1]) : nil } ?? .standard
        store.newGame(city: 0, mode: mode, perk: args.contains("-copper") ? .copper : nil)
        if let i = args.firstIndex(of: "-days"), i + 1 < args.count, let n = Int(args[i + 1]) {
            store.act { s in
                s.cash = 40_000
                for _ in 0..<n {
                    while let e = s.encounters.first { _ = try? Engine.resolve(&s, e.defaultChoice(s)) }
                    s.report = nil; s.outcome = nil
                    try? Engine.stay(&s)
                }
                if !args.contains("-keepOverlay") { s.report = nil; s.outcome = nil; s.encounters = [] }
            }
        }
        if args.contains("-holding") {
            store.act { s in
                for g in [2, 6, 12] { try? Engine.buy(&s, good: g, qty: min(6, Engine.maxBuy(s, good: g))) }
            }
        }
        if let i = args.firstIndex(of: "-call"), i + 1 < args.count, let caller = Int(args[i + 1]) {
            store.act { s in
                s.report = nil
                s.call = IncomingCall(caller: caller, fee: 90, trust: 0.55, line: Press.callOpeners[caller][0], answered: args.contains("-answered"))
            }
        }
        if let i = args.firstIndex(of: "-encounter"), i + 1 < args.count {
            store.act { s in
                s.report = nil
                switch args[i + 1] {
                case "police": s.encounters = [.police(Engine.policeStop(&s, airport: false))]
                case "collector": s.encounters = [.collector(Collector(loan: 0, owed: 12_500))]
                default: s.encounters = [.trouble(Engine.trouble(&s))]
                }
            }
        }
        if args.contains("-noCall") { store.act { $0.call = nil } }
        if args.contains("-raid") { store.act { $0.call = nil; $0.streak = 6; $0.raid = RaidAlert(city: $0.city, day: $0.day, seen: false) } }
        if args.contains("-endgood") {
            store.act { s in
                s.call = nil; s.report = nil; s.encounters = []
                s.cash = 1_850_000; s.rep = 82; s.heat = 20
                Engine.record(&s, 142_000, "Sold 60 Cocaine in Manchester")
                Engine.record(&s, -18_500, "Robbed by a small gang")
                for id in ["first_sale", "big_sale", "legend", "front"] { Engine.award(&s, id) }
                s.pendingEnding = true
                Engine.chooseEnding(&s, .spain)
            }
        }
        if args.contains("-enddead") {
            store.act { s in
                s.call = nil; s.report = nil; s.encounters = []
                Engine.record(&s, -9_200, "Nicked by the police")
                s.health = 0
                Engine.checkEnd(&s)
            }
        }
        if args.contains("-flashwin") { store.flash("Done Deal", "The Ecstasy moves without a hitch.", good: true, amount: 18_450) }
        if args.contains("-flashlose") { store.flash("Scammed", "The van never turns up. Neither does your money.", good: false, amount: -6_200) }
        if args.contains("-newgame") { screen = .newGame; return }
        if args.contains("-empire") {
            store.act { s in
                s.city = 1
                s.cash = 1_400_000
                s.dirty = 180_000
                s.turf = Array(repeating: 0, count: Catalog.cities.count); s.turf![1] = 52
                try? Engine.buyBusiness(&s, 0)
                try? Engine.hire(&s, 1)
                Engine.makeOffers(&s)
                if let o = s.offers?.first { try? Engine.acceptContract(&s, o.id) }
                s.notice = ""
            }
        }
        if args.contains("-ending") { store.act { s in s.day = s.maxDay; s.cash = 1_400_000; s.heat = 72; s.pendingEnding = true } }
        if args.contains("-rival") {
            store.act { s in
                s.city = 1
                var t = Engine.trouble(&s, attacker: 4); t.crew = Catalog.rivals[1]
                s.encounters = [.trouble(t)]
            }
        }
        if args.contains("-toast") { store.toast = Achievement.all[2] }
        if args.contains("-bigwin") { store.celebration = 48_250 }
        screen = .game
        #endif
    }

    private func go(_ s: Screen) {
        withAnimation(.easeInOut(duration: 0.45)) { screen = s }
        if s == .game { Audio.shared.duck() }
    }
}
