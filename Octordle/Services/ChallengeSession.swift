import Foundation
import Combine

/// The active Challenge session: consecutive Unlimited-style rounds (see
/// `GameViewModel.init(challenge:)`) played against a shared time budget or life
/// pool. Like Unlimited, Challenges are pure practice — this never touches
/// StatsService, achievements, or the daily save, only its own best-score record.
@MainActor
final class ChallengeSession: ObservableObject {
    let preset: ChallengeType

    /// One finished round's full board snapshot — powers the Review screen
    /// (board grids + answer list) and the Run per-round card.
    struct RoundResult: Identifiable {
        let id: Int          // 1-based round number
        let boards: [BoardData]
        var words: [String] { boards.map { $0.targetWord } }
        var solved: [Bool] { boards.map { $0.isSolved } }
        var solvedCount: Int { boards.filter { $0.isSolved }.count }
        var total: Int { boards.count }
        var isFlawless: Bool { solvedCount == total && total > 0 }
    }

    /// Cap on stored round snapshots (a long Run could otherwise grow unbounded);
    /// the Review shows the most recent rounds.
    private static let maxStoredRounds = 40

    /// Ticks down once per second while `.timed`; unused for `.run`.
    @Published private(set) var remainingSeconds: Int
    /// Decremented by unsolved-board count at the end of each round; unused for `.timed`.
    @Published private(set) var livesLeft: Int
    @Published private(set) var totalBoardsSolved = 0
    @Published private(set) var gamesCompleted = 0
    @Published private(set) var flawlessRounds = 0
    /// Every finished round, in order — used for the answer Review.
    @Published private(set) var rounds: [RoundResult] = []
    /// Run mode only: the just-finished round awaiting the player's "Continue"
    /// tap on its result card. `nil` when no card is showing.
    @Published private(set) var pendingRoundCard: RoundResult?
    @Published private(set) var isOver = false
    @Published private(set) var isNewBest = false
    /// Achievements unlocked by this session's final result (in display order).
    /// `ChallengeGameView` shows an unlock card per entry once the session ends —
    /// mirroring the daily flow. Set exactly once, in `finish()`.
    @Published private(set) var newlyUnlockedAchievements: [Achievement] = []
    /// `.timed` only — true when the player finished all `preset.gameTarget` games
    /// before the clock ran out (i.e. beat the challenge rather than timing out).
    @Published private(set) var didCompleteGoal = false
    /// Flips to true the instant the timed clock hits zero. GameViewModel observes
    /// this (via Combine, in `init(challenge:)`) to force-finish the round even
    /// mid-guess. Reset back to false once the round has been reported.
    @Published private(set) var timeExpired = false

    private(set) var bestScore: Int

    private var timer: Timer?

    init(preset: ChallengeType) {
        self.preset = preset
        self.remainingSeconds = preset.family == .timed ? preset.config : 0
        self.livesLeft = preset.family == .run ? preset.config : 0
        self.bestScore = Self.loadBest(for: preset.id)
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Lifecycle

    /// Begin the session — starts the countdown for `.timed` presets. `.run`
    /// presets need no timer; lives are only spent at round boundaries.
    func start() {
        guard preset.family == .timed else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard !isOver, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            timeExpired = true
        }
    }

    /// Called by `GameViewModel.endGame()` whenever a round finishes (naturally or
    /// via `forceFinishForChallenge()`). Folds the round's solved-board count into
    /// the running total and decides whether the session continues.
    func reportRoundEnd(boards: [BoardData]) {
        guard !isOver else { return }

        let boardsSolved = boards.filter { $0.isSolved }.count
        totalBoardsSolved += boardsSolved
        gamesCompleted += 1
        timeExpired = false // consumed by this report

        let result = RoundResult(id: gamesCompleted, boards: boards)
        rounds.append(result)
        if rounds.count > Self.maxStoredRounds { rounds.removeFirst() }
        if result.isFlawless { flawlessRounds += 1 }

        switch preset.family {
        case .timed:
            if preset.gameTarget > 0 && gamesCompleted >= preset.gameTarget {
                didCompleteGoal = true
                finish()
            } else if remainingSeconds <= 0 {
                finish()
            }
        case .run:
            let unsolved = max(0, result.total - boardsSolved)
            livesLeft -= unsolved
            if livesLeft <= 0 {
                finish()
            } else {
                // Pause on a per-round result card; ChallengeGameView deals the
                // next round when the player taps Continue.
                pendingRoundCard = result
            }
        }
    }

    /// Dismiss the Run per-round card (player tapped Continue).
    func clearPendingRoundCard() {
        pendingRoundCard = nil
    }

    /// Pop the front achievement unlock card once the player dismisses it, so the
    /// next queued one can animate in (see `ChallengeGameView`).
    func dismissTopAchievement() {
        guard !newlyUnlockedAchievements.isEmpty else { return }
        newlyUnlockedAchievements.removeFirst()
    }

    func finish() {
        guard !isOver else { return }
        timer?.invalidate()
        timer = nil
        isOver = true
        if totalBoardsSolved > bestScore {
            isNewBest = true
            bestScore = totalBoardsSolved
            Self.saveBest(totalBoardsSolved, for: preset.id)
        }
        // Longest survival (rounds completed) — drives the Run achievements.
        if gamesCompleted > Self.loadBestRounds(for: preset.id) {
            Self.saveBestRounds(gamesCompleted, for: preset.id)
        }
        // Evaluate Explore-mode achievements now that best records are up to date,
        // so ChallengeGameView can present unlock cards (same flow as daily).
        newlyUnlockedAchievements = StatsService.shared.evaluateSpecialAchievements()
    }

    /// Restart from scratch with the same preset — used by "Play Again".
    func reset() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = preset.family == .timed ? preset.config : 0
        livesLeft = preset.family == .run ? preset.config : 0
        totalBoardsSolved = 0
        gamesCompleted = 0
        flawlessRounds = 0
        rounds = []
        pendingRoundCard = nil
        isOver = false
        isNewBest = false
        didCompleteGoal = false
        timeExpired = false
        start()
    }

    // MARK: - Best score persistence

    private static func key(for presetId: String) -> String {
        "octordle_challengeBest_\(presetId)"
    }

    /// Best `totalBoardsSolved` ever recorded for a preset, or 0 if never played.
    static func loadBest(for presetId: String) -> Int {
        UserDefaults.standard.integer(forKey: key(for: presetId))
    }

    private static func saveBest(_ value: Int, for presetId: String) {
        UserDefaults.standard.set(value, forKey: key(for: presetId))
    }

    // MARK: - Best rounds persistence (longest survival)

    private static func roundsKey(for presetId: String) -> String {
        "octordle_challengeRounds_\(presetId)"
    }

    /// Most rounds ever completed in a single session of this preset (survival
    /// length), or 0 if never played.
    static func loadBestRounds(for presetId: String) -> Int {
        UserDefaults.standard.integer(forKey: roundsKey(for: presetId))
    }

    private static func saveBestRounds(_ value: Int, for presetId: String) {
        UserDefaults.standard.set(value, forKey: roundsKey(for: presetId))
    }
}
