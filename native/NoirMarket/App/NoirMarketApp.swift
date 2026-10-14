import SwiftUI

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
                .task {
                    unlock.onChange = { [store] entitled in store.fullAccess = entitled }
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
                          onContinue: { go(.game) },
                          onNewGame: { go(.newGame) },
                          onHowTo: { sheet = .howTo },
                          onSettings: { sheet = .settings },
                          onRecords: { sheet = .records })
                    .transition(.opacity)
            case .newGame:
                NewGameView(onStart: { city in
                    store.newGame(city: city)
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
            case .howTo: HowToPlayView()
            case .settings: SettingsView(inGame: false, onAbandon: {})
            case .records: RecordsView()
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
        guard args.contains("-demo") else { return }
        store.newGame(city: 0)
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
        screen = .game
        #endif
    }

    private func go(_ s: Screen) {
        withAnimation(.easeInOut(duration: 0.45)) { screen = s }
        if s == .game { Audio.shared.duck() }
    }
}
