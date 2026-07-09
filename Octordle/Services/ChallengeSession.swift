import Foundation
import Combine

/// The active Challenge session: consecutive Unlimited-style rounds (see
/// `GameViewModel.init(challenge:)`) played against a shared time budget or life
/// pool. Like Unlimited, Challenges are pure practice — this never touches
/// StatsService, achievements, or the daily save, only its own best-score record.
@MainActor
final class ChallengeSession: ObservableObject {
    let preset: ChallengeType

    /// Ticks down once per second while `.timed`; unused for `.run`.
    @Published private(set) var remainingSeconds: Int
    /// Decremented by unsolved-board count at the end of each round; unused for `.timed`.
    @Published private(set) var livesLeft: Int
    @Published private(set) var totalBoardsSolved = 0
    @Published private(set) var gamesCompleted = 0
    @Published private(set) var isOver = false
    @Published private(set) var isNewBest = false
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
    func reportRoundEnd(boardsSolved: Int) {
        guard !isOver else { return }

        totalBoardsSolved += boardsSolved
        gamesCompleted += 1
        timeExpired = false // consumed by this report

        switch preset.family {
        case .timed:
            if remainingSeconds <= 0 {
                finish()
            }
        case .run:
            let unsolved = max(0, Constants.Game.defaultDifficulty.boardCount - boardsSolved)
            livesLeft -= unsolved
            if livesLeft <= 0 {
                finish()
            }
        }
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
    }

    /// Restart from scratch with the same preset — used by "Play Again".
    func reset() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = preset.family == .timed ? preset.config : 0
        livesLeft = preset.family == .run ? preset.config : 0
        totalBoardsSolved = 0
        gamesCompleted = 0
        isOver = false
        isNewBest = false
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
}
