import Foundation
import GameKit
import UIKit

/// A single row to display on the leaderboard.
struct LeaderboardRow: Identifiable {
    let id = UUID()
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool

    /// Boards solved, decoded from the composite score.
    var boardsSolved: Int { GameCenterService.decode(score: score).solved }
    /// Octordle "golf" guess total, decoded from the composite score.
    var guessTotal: Int { GameCenterService.decode(score: score).guessTotal }
}

/// Manages Game Center authentication and the daily Octordle leaderboard.
///
/// Scoring is encoded into a single integer so that "boards solved" always
/// dominates "guesses used" (see `dailyScore(for:)`). Lower is better.
@MainActor
final class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    enum LoadState: Equatable {
        case notAuthenticated
        case loading
        case loaded
        case failed
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var loadState: LoadState = .notAuthenticated

    /// Top entries for the current daily period.
    @Published private(set) var topRows: [LeaderboardRow] = []
    /// The local player's own entry, if they've posted a score today.
    @Published private(set) var localRow: LeaderboardRow?
    /// Total number of players on the board this period.
    @Published private(set) var totalPlayers: Int = 0

    private init() {}

    // MARK: - Score Encoding

    /// Composite daily score. Lower is better.
    ///
    /// `(unsolved boards) × unsolvedWeight + (sum of solve rows, unsolved = maxGuesses + 1)`
    ///
    /// Because the guess component can never reach `unsolvedWeight`, solving more
    /// boards always beats solving fewer, regardless of guess count. Guesses only
    /// break ties between players who solved the same number of boards.
    nonisolated static func dailyScore(for state: GameState) -> Int {
        let penalty = state.difficulty.maxGuesses + 1
        let guessTotal = state.boards.reduce(0) { $0 + ($1.solvedAtGuess ?? penalty) }
        let unsolved = state.boards.filter { !$0.isSolved }.count
        return unsolved * Constants.GameCenter.unsolvedWeight + guessTotal
    }

    /// Decode a composite score back into a human-readable (solved, guessTotal) pair.
    nonisolated static func decode(score: Int, boardCount: Int = Constants.GameCenter.boardCount) -> (solved: Int, guessTotal: Int) {
        let unsolved = score / Constants.GameCenter.unsolvedWeight
        let guessTotal = score % Constants.GameCenter.unsolvedWeight
        return (boardCount - unsolved, guessTotal)
    }

    // MARK: - Authentication

    /// Set the Game Center authentication handler. Safe to call once at launch.
    func authenticate() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.present(viewController)
                    return
                }
                if player.isAuthenticated {
                    print("[GameCenter] Authenticated as \(player.displayName)")
                    self.isAuthenticated = true
                    // If today's puzzle was already completed (e.g. before Game Center
                    // finished signing in, or in an earlier build), submit that saved
                    // first-attempt result now. "Best Score" makes this idempotent.
                    self.submitTodaysResultIfNeeded()
                    await self.loadLeaderboard()
                } else {
                    self.isAuthenticated = false
                    self.loadState = .notAuthenticated
                    if let error {
                        print("[GameCenter] Authentication failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private static func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        // Walk to the top-most presented controller.
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(viewController, animated: true)
    }

    // MARK: - Submitting

    /// Submit the daily result. No-op if not authenticated or not a daily game.
    func submitDailyScore(for state: GameState) {
        guard isAuthenticated, state.mode == .daily else { return }
        let score = Self.dailyScore(for: state)
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [Constants.GameCenter.dailyLeaderboardID]
                )
                print("[GameCenter] Submitted score \(score) to \(Constants.GameCenter.dailyLeaderboardID)")
                StatsService.shared.markLeaderboardSubmitted()
                await loadLeaderboard()
            } catch {
                print("[GameCenter] Score submission failed: \(error.localizedDescription)")
            }
        }
    }

    /// Submit today's already-completed daily result, if there is one.
    /// Uses the saved first-attempt result, so it's safe against replay cheating.
    func submitTodaysResultIfNeeded() {
        guard isAuthenticated,
              let state = StatsService.shared.loadCompletedDailyResult(),
              state.mode == .daily else { return }
        submitDailyScore(for: state)
    }

    // MARK: - Loading

    /// Load the current daily period's top entries plus the local player's rank.
    func loadLeaderboard() async {
        guard isAuthenticated else {
            loadState = .notAuthenticated
            return
        }
        loadState = .loading
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(
                IDs: [Constants.GameCenter.dailyLeaderboardID]
            )
            guard let board = boards.first else {
                print("[GameCenter] Leaderboard '\(Constants.GameCenter.dailyLeaderboardID)' not found — check the ID matches App Store Connect.")
                loadState = .failed
                return
            }

            // Recurring leaderboards scope to the current occurrence already, so
            // entries are read with .allTime (NOT .today, which returns nothing here).
            let (localEntry, entries, total) = try await board.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: 10)
            )
            print("[GameCenter] Loaded \(entries.count) entries, total players: \(total), localEntry: \(localEntry != nil)")

            let localID = GKLocalPlayer.local.gamePlayerID
            topRows = entries.map { entry in
                LeaderboardRow(
                    rank: entry.rank,
                    displayName: entry.player.displayName,
                    score: entry.score,
                    isLocalPlayer: entry.player.gamePlayerID == localID
                )
            }
            localRow = localEntry.map { entry in
                LeaderboardRow(
                    rank: entry.rank,
                    displayName: entry.player.displayName,
                    score: entry.score,
                    isLocalPlayer: true
                )
            }
            totalPlayers = total
            loadState = .loaded
        } catch {
            print("[GameCenter] Failed to load leaderboard: \(error.localizedDescription)")
            loadState = .failed
        }
    }

    /// Percentage of players the local player ranks ahead of (0–100).
    /// Returns nil if the local player hasn't posted a score this period.
    var percentileBeaten: Int? {
        guard let rank = localRow?.rank, totalPlayers > 0 else { return nil }
        let beaten = Double(totalPlayers - rank) / Double(totalPlayers) * 100
        return max(0, Int(beaten.rounded()))
    }
}
