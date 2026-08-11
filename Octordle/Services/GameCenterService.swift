import GameKit
import SwiftUI
import UIKit

/// Game Center integration for the daily ranked leaderboard ("Daily Rank").
///
/// Score encoding (higher is better, matching the leaderboard's "High to Low"):
///   score = solvedBoards * 1,000,000
///         + (maxGuesses - guessCount) * 10,000   // fewer guesses → higher
///         + max(0, 3600 - elapsedSeconds)         // faster → higher (capped at 1h)
/// This orders by boards solved, then guesses, then time. Losses (not all solved,
/// all guesses used) naturally sort below wins.
@MainActor
final class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    /// Must match the Leaderboard ID configured in App Store Connect.
    /// (`daily_rank` was already taken by another app, hence the suffix.)
    static let dailyLeaderboardID = "daily_rank_oct"

    /// The daily board is small early in the day and while the app is young, so a
    /// raw player count reads as "nobody plays this". Only show the total once the
    /// board is busy enough for the number to help rather than hurt.
    static let minPlayersToShowTotal = 50

    @Published private(set) var isAuthenticated = false

    private init() {}

    // MARK: - Authentication

    /// Set the authentication handler. Call once, early (e.g. main tab appears).
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    Self.present(viewController)
                }
                if let error {
                    print("[GameCenter] auth error: \(error.localizedDescription)")
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - Scoring

    static func encodeScore(solvedBoards: Int, guessCount: Int, maxGuesses: Int, elapsedSeconds: Int) -> Int {
        let boards = solvedBoards * 1_000_000
        let guesses = max(0, maxGuesses - guessCount) * 10_000
        let speed = max(0, 3600 - elapsedSeconds)
        return boards + guesses + speed
    }

    struct DecodedScore {
        let solvedBoards: Int
        let guessCount: Int
        let elapsedSeconds: Int
    }

    static func decodeScore(_ score: Int, maxGuesses: Int) -> DecodedScore {
        let boards = score / 1_000_000
        let remainder = score % 1_000_000
        let guessesSaved = remainder / 10_000
        let speed = remainder % 10_000
        return DecodedScore(
            solvedBoards: boards,
            guessCount: maxGuesses - guessesSaved,
            elapsedSeconds: 3600 - speed
        )
    }

    // MARK: - Submit

    func submitDailyScore(solvedBoards: Int, guessCount: Int, maxGuesses: Int, elapsedSeconds: Int) async {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let score = Self.encodeScore(
            solvedBoards: solvedBoards,
            guessCount: guessCount,
            maxGuesses: maxGuesses,
            elapsedSeconds: elapsedSeconds
        )
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.dailyLeaderboardID]
            )
        } catch {
            print("[GameCenter] submit failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Load

    /// Load the current daily occurrence: the local player's entry + the top entries
    /// + the total number of players who submitted a score today.
    func loadDailyEntries(top count: Int = 50) async -> (local: GKLeaderboard.Entry?, entries: [GKLeaderboard.Entry], total: Int)? {
        guard GKLocalPlayer.local.isAuthenticated else { return nil }
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.dailyLeaderboardID])
            guard let board = leaderboards.first else { return nil }
            let range = NSRange(location: 1, length: max(1, count))
            let (localEntry, entries, total) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: range
            )
            return (localEntry, entries, total)
        } catch {
            print("[GameCenter] load failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Lightweight: the local player's current daily rank and the total player count.
    func loadLocalDailyRank() async -> (rank: Int, total: Int)? {
        guard GKLocalPlayer.local.isAuthenticated else { return nil }
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.dailyLeaderboardID])
            guard let board = leaderboards.first else { return nil }
            let (localEntry, _, total) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 1)
            )
            guard let localEntry else { return nil }
            return (localEntry.rank, total)
        } catch {
            print("[GameCenter] rank load failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func present(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? windowScene.windows.first?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(viewController, animated: true)
    }
}
