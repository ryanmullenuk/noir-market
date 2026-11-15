import GameKit
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Thin Game Center wrapper: sign-in, leaderboard scores, achievements and the dashboard.
/// Everything is optional; the game plays the same signed out.
@MainActor
enum GameCenter {
    static var signedIn: Bool { GKLocalPlayer.local.isAuthenticated }

    static func authenticate() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-noGameCenter") || args.contains("-demo") { return }
        #endif
        GKLocalPlayer.local.authenticateHandler = { vc, _ in
            Task { @MainActor in
                if let vc { present(vc) }
            }
        }
    }

    static func submit(score: Int, leaderboard: String) {
        guard signedIn, score > 0 else { return }
        Task { try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard]) }
    }

    /// One row of a global leaderboard.
    struct Entry: Identifiable, Sendable {
        let id: String
        let rank: Int
        let name: String
        let score: Int
        let isMe: Bool
    }

    /// The global top players for a leaderboard, plus the signed-in player's own entry.
    /// Recurring boards (the Daily Challenge) return today's occurrence.
    static func top(_ leaderboard: String, count: Int = 10) async throws -> (top: [Entry], me: Entry?, total: Int) {
        guard signedIn else { return ([], nil, 0) }
        guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboard]).first else { return ([], nil, 0) }
        let (local, entries, total) = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: count))
        let myID = GKLocalPlayer.local.gamePlayerID
        func convert(_ e: GKLeaderboard.Entry) -> Entry {
            Entry(id: e.player.gamePlayerID + "-\(e.rank)", rank: e.rank, name: e.player.displayName,
                  score: e.score, isMe: e.player.gamePlayerID == myID)
        }
        return (entries.map(convert), local.map(convert), total)
    }

    /// Posts a score and waits for it to land, so the player's new global rank can be shown straight after.
    static func submitAndRank(score: Int, leaderboard: String) async -> (rank: Int, total: Int)? {
        guard signedIn, score > 0 else { return nil }
        try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard])
        guard let result = try? await top(leaderboard, count: 1), let me = result.me else { return nil }
        return (me.rank, result.total)
    }

    static func report(achievement id: String) {
        guard signedIn else { return }
        let a = GKAchievement(identifier: "noir.ach.\(id)")
        a.percentComplete = 100
        a.showsCompletionBanner = false
        Task { try? await GKAchievement.report([a]) }
    }

    static func showLeaderboard(_ id: String) {
        guard signedIn else { authenticate(); return }
        #if os(iOS)
        let vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = Dismisser.shared
        present(vc)
        #else
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
        #endif
    }

    #if os(iOS)
    private static func present(_ vc: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(vc, animated: true)
    }

    final class Dismisser: NSObject, GKGameCenterControllerDelegate, @unchecked Sendable {
        static let shared = Dismisser()
        nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            Task { @MainActor in gameCenterViewController.dismiss(animated: true) }
        }
    }
    #else
    /// Shows Game Center's sign-in sheet over the main window.
    private static func present(_ vc: NSViewController) {
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else { return }
        window.contentViewController?.presentAsSheet(vc)
    }
    #endif
}
