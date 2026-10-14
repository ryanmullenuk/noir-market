import GameKit
import UIKit

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

    static func report(achievement id: String) {
        guard signedIn else { return }
        let a = GKAchievement(identifier: "noir.ach.\(id)")
        a.percentComplete = 100
        a.showsCompletionBanner = false
        Task { try? await GKAchievement.report([a]) }
    }

    static func showLeaderboard(_ id: String) {
        guard signedIn else { authenticate(); return }
        let vc = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        vc.gameCenterDelegate = Dismisser.shared
        present(vc)
    }

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
}
