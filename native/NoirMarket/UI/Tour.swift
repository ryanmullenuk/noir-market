import SwiftUI
import Observation

/// A guided tour of every part of the game. It plays on a throwaway demo game, so the player's
/// own save, records, achievements and leaderboards are never touched.
///
/// Players get it skippable, step by step (offered once on first launch, replayable from How to Play).
/// Debug builds can run it hands-free for screen recording: `-tourRecord` (with captions) or
/// `-tourRecord -tourClean` (no card, for trailer footage).
@MainActor
@Observable
final class Tour {
    static let shared = Tour()

    enum Scene: String { case title, newGame, market, trade, stats, travel, noirnet, call, police, raid, money, street, ending, caseFile, leaderboard, finish }
    /// Where the tour card is drawn: over the main screen, over a sheet, or over the full-screen overlay.
    enum Layer { case root, sheet, cover }

    struct Step {
        let scene: Scene
        let title: String
        let text: String
        let layer: Layer
        /// Seconds the step is held when recording.
        let hold: Double
    }

    let steps: [Step] = [
        Step(scene: .title, title: "Welcome to Noir Market", text: "Thirty nights to turn £2,500 into a fortune across the UK and Ireland. Here’s the tour.", layer: .root, hold: 4),
        Step(scene: .newGame, title: "Pick your poison", text: "Choose a mode, a background with an edge and a cost, and the city you start in.", layer: .root, hold: 4),
        Step(scene: .market, title: "Read the market", text: "Every city has goods that go cheap and goods that sell dear. Prices move every night.", layer: .root, hold: 4.5),
        Step(scene: .trade, title: "Buy low, sell high", text: "Tap a drug to trade. You see what you paid, what you’d make, and how big orders move the price.", layer: .sheet, hold: 4),
        Step(scene: .stats, title: "Health, heat, respect", text: "Tap any stat to learn what it does. Heat brings the police. Respect brings better deals.", layer: .root, hold: 4),
        Step(scene: .travel, title: "Keep moving", text: "Fourteen cities. Your bag’s value in each is estimated for you, so you know where to head.", layer: .sheet, hold: 4.5),
        Step(scene: .noirnet, title: "Half the news is true", text: "Every morning NOIRNET brings rumours, tips and price shocks. Nobody tells you which half is real.", layer: .cover, hold: 5),
        Step(scene: .call, title: "Trust no one", text: "Informants call with tips for a fee. Pay them and they stay loyal. Stiff them and they talk.", layer: .root, hold: 4),
        Step(scene: .police, title: "Every stop is a gamble", text: "Bribe, run, fight or go quietly. The odds are always on screen.", layer: .cover, hold: 4.5),
        Step(scene: .raid, title: "The heat is coming", text: "Stay in one city too long and Breaking News warns you a raid is on its way.", layer: .root, hold: 4.5),
        Step(scene: .money, title: "Bank, borrow, launder", text: "Bank cash so it can’t be stolen, borrow from five lenders, buy fronts to wash dirty money.", layer: .sheet, hold: 4.5),
        Step(scene: .street, title: "Build an empire", text: "Take delivery contracts and hire a driver, a lookout or some muscle.", layer: .sheet, hold: 4.5),
        Step(scene: .ending, title: "How does it end?", text: "On the last night: retire to Spain, risk one last score, or walk away.", layer: .cover, hold: 4.5),
        Step(scene: .caseFile, title: "The case file", text: "Every game ends with a NOIRNET case file: your rank, best deals, worst hits and a verdict.", layer: .cover, hold: 6),
        Step(scene: .leaderboard, title: "Beat the world", text: "Global Game Center leaderboards for every mode, and a Daily Challenge where everyone gets the same luck.", layer: .sheet, hold: 4.5),
        Step(scene: .finish, title: "Your move", text: "Thirty nights. Nobody’s clean. Tap New Game when you’re ready.", layer: .root, hold: 4),
    ]

    private(set) var active = false
    private(set) var index = 0
    /// Hands-free for screen recording.
    private(set) var recording = false
    /// Recording without the card, for trailer footage.
    private(set) var clean = false

    var current: Step? { active ? steps[index] : nil }

    private var autoTask: Task<Void, Never>?
    private var timeline: [[String: Any]] = []

    func start(recording: Bool = false, clean: Bool = false) {
        guard !active else { return }
        self.recording = recording
        self.clean = clean
        index = 0
        timeline = []
        active = true
        mark()
        if recording { scheduleAuto() }
    }

    func next() {
        guard active else { return }
        Audio.shared.play(.click, volume: 0.4)
        if index + 1 < steps.count {
            index += 1
            mark()
            if recording { scheduleAuto() }
        } else {
            finish()
        }
    }

    func finish() {
        autoTask?.cancel()
        active = false
        UserDefaults.standard.set(true, forKey: "tourOffered")
        if recording { writeTimeline() }
    }

    private func scheduleAuto() {
        autoTask?.cancel()
        let hold = steps[index].hold
        autoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            next()
        }
    }

    /// Records when each step began, so the trailer tool can find every scene in the recording.
    private func mark() {
        guard recording else { return }
        timeline.append(["scene": steps[index].scene.rawValue, "at": Date().timeIntervalSince1970])
    }

    private func writeTimeline() {
        timeline.append(["scene": "end", "at": Date().timeIntervalSince1970])
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: timeline, options: .prettyPrinted) else { return }
        try? data.write(to: docs.appendingPathComponent("tour-timeline.json"))
    }
}

/// Sets up the demo game for each tour scene. Every scene starts from the same seeded base game.
@MainActor
enum TourScenes {
    static func base() -> GameState {
        var s = GameState(seed: 1947, city: 0, name: "You", fullAccess: true)
        Engine.configure(&s, mode: .standard, perk: nil)
        s.cash = 40_000
        for _ in 0..<3 {
            while let e = s.encounters.first { _ = try? Engine.resolve(&s, e.defaultChoice(s)) }
            s.report = nil; s.outcome = nil
            try? Engine.stay(&s)
        }
        while let e = s.encounters.first { _ = try? Engine.resolve(&s, e.defaultChoice(s)) }
        s.report = nil; s.outcome = nil; s.encounters = []; s.call = nil; s.raid = nil; s.streak = 0
        for g in [2, 6, 12] { try? Engine.buy(&s, good: g, qty: min(6, Engine.maxBuy(s, good: g))) }
        s.notice = ""
        s.unlocked = nil
        return s
    }

    /// The game state a scene needs, or nil to leave the state as it is.
    static func state(for scene: Tour.Scene) -> GameState? {
        var s = base()
        switch scene {
        case .title, .newGame, .finish, .leaderboard:
            return nil
        case .market, .trade, .stats, .travel:
            break
        case .noirnet:
            while let e = s.encounters.first { _ = try? Engine.resolve(&s, e.defaultChoice(s)) }
            try? Engine.stay(&s)
            s.encounters = []; s.outcome = nil; s.call = nil; s.raid = nil
        case .call:
            s.call = IncomingCall(caller: 1, fee: 90, trust: 0.55, line: Press.callOpeners[1][0], answered: false)
        case .police:
            s.encounters = [.police(Engine.policeStop(&s, airport: false))]
        case .raid:
            s.streak = 6
            s.raid = RaidAlert(city: s.city, day: s.day, seen: false)
        case .money:
            s.cash = 120_000
            s.dirty = 64_000
            try? Engine.buyBusiness(&s, 0)
        case .street:
            s.city = 1
            s.cash = 1_400_000
            s.turf = Array(repeating: 0, count: Catalog.cities.count); s.turf![1] = 52
            try? Engine.hire(&s, 1)
            Engine.makeOffers(&s)
            if let o = s.offers?.first { try? Engine.acceptContract(&s, o.id) }
        case .ending:
            s.day = s.maxDay; s.cash = 1_400_000; s.heat = 72; s.pendingEnding = true
        case .caseFile:
            s.cash = 1_850_000; s.rep = 82; s.heat = 20
            Engine.record(&s, 142_000, "Sold 60 Cocaine in Manchester")
            Engine.record(&s, -18_500, "Robbed by a small gang")
            s.stats.unitsBought = 412; s.stats.unitsSold = 398; s.stats.trips = 19; s.stats.bribesPaid = 3; s.stats.fightsWon = 2
            s.visited = [0, 1, 2, 3, 5, 8, 9]
            s.pendingEnding = true
            Engine.chooseEnding(&s, .spain)
        }
        s.notice = ""
        s.unlocked = nil
        return s
    }
}

/// The tour card: what you're looking at, with Next and Skip. Drawn on the layer the current
/// step lives on, so it sits above sheets and the full-screen overlay too.
private struct TourCardModifier: ViewModifier {
    let layer: Tour.Layer
    @State private var tour = Tour.shared

    func body(content: Content) -> some View {
        let showing = tour.active && tour.current?.layer == layer
        content
            .allowsHitTesting(!tour.active)
            .overlay(alignment: .bottom) {
                if showing, let step = tour.current, !tour.clean {
                    TourCard(step: step, number: tour.index + 1, count: tour.steps.count, recording: tour.recording)
                        .id(tour.index)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: tour.index)
            #if os(iOS)
            .interactiveDismissDisabled(tour.active)
            #endif
    }
}

private struct TourCard: View {
    let step: Tour.Step
    let number: Int
    let count: Int
    let recording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Noir.green).frame(width: 7, height: 7).glow(Noir.green, radius: 5)
                Text("TOUR · \(number)/\(count)").font(Noir.label(10)).tracking(1.4).foregroundStyle(Noir.green)
                Spacer()
                if !recording {
                    Button("Skip tour") { Tour.shared.finish() }
                        .font(Noir.label(10)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(Noir.silver)
                        .accessibilityHint("Ends the tour")
                }
            }
            Text(step.title).font(Noir.display(22)).foregroundStyle(Noir.paper)
            Text(step.text).font(Noir.ui(13)).foregroundStyle(Noir.silver)
                .fixedSize(horizontal: false, vertical: true)
            if !recording {
                HStack(spacing: 10) {
                    ProgressDots(number: number, count: count)
                    Spacer()
                    Button {
                        Tour.shared.next()
                    } label: {
                        Text(number == count ? "Let’s go" : "Next  ›")
                            .padding(.horizontal, 22)
                    }
                    .buttonStyle(NoirButtonStyle(kind: .primary))
                    .frame(width: 150)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Noir.ink.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Noir.green.opacity(0.7), lineWidth: 1.2))
        .shadow(color: Noir.green.opacity(0.3), radius: 18)
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
        .contentShape(Rectangle())
        .onTapGesture { if !recording { Tour.shared.next() } }
        .buttonStyle(.plain)
    }
}

private struct ProgressDots: View {
    let number: Int
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...count, id: \.self) { i in
                Capsule().fill(i <= number ? Noir.green : Color.white.opacity(0.15))
                    .frame(width: i == number ? 12 : 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Shows the tour card when the current step lives on this layer, and blocks touches while touring.
    func tourCard(_ layer: Tour.Layer) -> some View { modifier(TourCardModifier(layer: layer)) }
}

extension Notification.Name {
    static let noirTour = Notification.Name("noirTour")
}
