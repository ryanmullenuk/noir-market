import Foundation
import Observation
import SwiftUI

struct Record: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var worth: Int
    var rank: Int
    var died: Bool
    var date: Date
    var fullGame: Bool
    var seed: UInt64 = 0
    var mode: String?
}

/// Owns the live game, saves after every change, and keeps the records table.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState?
    private(set) var records: [Record] = []
    var error: String?
    /// Achievement just earned, for the banner.
    var toast: Achievement?
    /// A big win to celebrate with the slow-motion moment.
    var celebration: Int?
    /// The centre-screen result alert currently showing.
    var flashing: Flash?
    private(set) var achievements: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "achievements") ?? [])
    var fullAccess = false {
        didSet {
            let god = state?.godMode == true || Self.isTesterName(state?.playerName ?? "")
            let daily = state?.mode == GameMode.daily.rawValue
            state?.fullAccess = !daily && (fullAccess || god)
            persist()
        }
    }

    static let godCash = 99_999_999
    static func isGodName(_ name: String) -> Bool { name.trimmingCharacters(in: .whitespaces).uppercased() == "GODMODE" }
    /// TESTER opens every city but plays with normal money, for honest test runs.
    static func isTesterName(_ name: String) -> Bool { name.trimmingCharacters(in: .whitespaces).uppercased() == "TESTER" }
    /// Any test name that unlocks all cities.
    static func unlocksAll(_ name: String) -> Bool { isGodName(name) || isTesterName(name) }

    private let saveURL: URL
    private let recordsURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("noir-save.json")
        recordsURL = dir.appendingPathComponent("noir-records.json")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetSave") { try? FileManager.default.removeItem(at: saveURL) }
        #endif
        if let data = try? Data(contentsOf: saveURL), let saved = try? JSONDecoder().decode(GameState.self, from: data), saved.over == nil {
            state = saved
        }
        if let data = try? Data(contentsOf: recordsURL), let saved = try? JSONDecoder().decode([Record].self, from: data) {
            records = saved
        }
    }

    var hasSave: Bool { state != nil && state?.over == nil }

    var playerName: String {
        get { UserDefaults.standard.string(forKey: "playerName") ?? "" }
        set { UserDefaults.standard.set(String(newValue.prefix(20)), forKey: "playerName") }
    }

    func newGame(city: Int, mode: GameMode = .standard, perk: Perk? = nil) {
        let seed: UInt64 = mode == .daily ? GameMode.dailySeed() : mode == .tutorial ? 2026 : UInt64.random(in: 1...UInt64.max)
        let start = mode == .daily || mode == .tutorial ? 0 : city
        let god = Self.isGodName(playerName)
        let tester = Self.isTesterName(playerName)
        var s = GameState(seed: seed, city: start, name: playerName, fullAccess: mode != .daily && (fullAccess || god || tester))
        Engine.configure(&s, mode: mode, perk: perk)
        if god {
            // Test mode: every city and a bottomless wallet.
            s.godMode = true
            s.cash = Self.godCash
            s.notice = "GODMODE. Every city is open and the money never runs out. Nothing here counts for the records."
        }
        if tester && !god {
            s.notice = "TESTER. Every city is open. Normal money, normal rules."
        }
        state = s
        persist()
    }

    func abandon() {
        state = nil
        try? FileManager.default.removeItem(at: saveURL)
    }

    /// Runs a game action, saving on success and surfacing the error text on failure.
    @discardableResult
    func act(_ action: (inout GameState) throws -> Void) -> Bool {
        guard var s = state else { return false }
        do {
            try action(&s)
            if s.godMode == true, s.over == nil { s.cash = max(s.cash, Self.godCash) }
            drainProgress(&s)
            state = s
            finishIfOver()
            persist()
            return true
        } catch {
            self.error = error.localizedDescription
            Audio.shared.buzz(.warning)
            return false
        }
    }

    /// Files new achievements, reports them to Game Center, and queues celebrations.
    private func drainProgress(_ s: inout GameState) {
        for id in s.unlocked ?? [] where !achievements.contains(id) {
            achievements.insert(id)
            UserDefaults.standard.set(Array(achievements), forKey: "achievements")
            GameCenter.report(achievement: id)
            if let a = Achievement.all.first(where: { $0.id == id }) { toast = a }
        }
        s.unlocked = nil
        // Big wins are now shown by the result alert at the point of the action.
        s.lastBigWin = nil
    }

    func clearOutcome() {
        state?.outcome = nil
        persist()
    }

    func clearReport() {
        state?.report = nil
        persist()
    }

    private func finishIfOver() {
        guard let s = state, let over = s.over, s.godMode != true else { return }
        let mode = Engine.mode(s)
        guard mode != .tutorial else { return }
        if let i = records.firstIndex(where: { $0.seed == s.seed }) {
            // Same seed (a replayed Daily Challenge): keep the better run.
            guard over.worth > records[i].worth else { return }
            records.remove(at: i)
        }
        let record = Record(name: s.playerName.isEmpty ? "Anonymous" : s.playerName, worth: over.worth, rank: over.rank,
                            died: over.died, date: .now, fullGame: s.fullAccess, seed: s.seed, mode: mode.rawValue)
        if let board = mode.leaderboard { GameCenter.submit(score: over.worth, leaderboard: board) }
        records.append(record)
        records.sort { $0.worth > $1.worth }
        records = Array(records.prefix(20))
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: recordsURL, options: .atomic) }
    }

    func persist() {
        guard let s = state else { return }
        if s.over != nil {
            // Finished games are not resumable, so a reload can’t undo a death.
            try? FileManager.default.removeItem(at: saveURL)
            return
        }
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: saveURL, options: .atomic) }
    }
}
