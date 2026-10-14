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
}

/// Owns the live game, saves after every change, and keeps the records table.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState?
    private(set) var records: [Record] = []
    var error: String?
    var fullAccess = false {
        didSet {
            state?.fullAccess = fullAccess
            persist()
        }
    }

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

    func newGame(city: Int) {
        let seed = UInt64.random(in: 1...UInt64.max)
        state = GameState(seed: seed, city: city, name: playerName, fullAccess: fullAccess)
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

    func clearOutcome() {
        state?.outcome = nil
        persist()
    }

    func clearReport() {
        state?.report = nil
        persist()
    }

    private func finishIfOver() {
        guard let s = state, let over = s.over else { return }
        guard !records.contains(where: { $0.seed == s.seed }) else { return }
        let record = Record(name: s.playerName.isEmpty ? "Anonymous" : s.playerName, worth: over.worth, rank: over.rank,
                            died: over.died, date: .now, fullGame: s.fullAccess, seed: s.seed)
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
