import SwiftUI
import Combine

/// Main game view model
@MainActor
class GameViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var gameState: GameState
    @Published var showInvalidWordAlert = false
    @Published var showGameCompleteSheet = false
    /// The count-up clock lives in its own observable object: it changes every
    /// second, and if it were `@Published` here, every tick would invalidate the
    /// whole game screen — all 8 boards, 520 tiles and the keyboard. Only
    /// `GameTimerLabel` observes it.
    let clock = GameClock()
    @Published var invalidWordMessage = ""
    @Published var shakingBoardIndex: Int? = nil
    @Published var isNotepadOpen = false
    @Published var notepadText = ""
    @Published var newlyUnlockedTheme: BoardTheme? = nil
    @Published var newlyUnlockedAchievements: [Achievement] = []
    /// Cached post-game analysis. Computed once (see `ensureSolveReport`) so flipping
    /// between the board and the result card never recomputes it.
    @Published var solveReport: SolveReport? = nil
    private var isComputingSolveReport = false

    /// The active Challenge session, if this game is a Challenge round (Timed/Run
    /// preset). Weak — `ChallengeGameView` owns the session as a `@StateObject`;
    /// this view model only reports round results into it. When set, `endGame()`
    /// reports to the session instead of showing the normal result sheet.
    weak var challengeSession: ChallengeSession?

    // MARK: - Services

    private let wordService = WordService.shared
    private let statsService = StatsService.shared
    private let dailyPuzzleService = DailyPuzzleService.shared

    // Builds the Solve Report incrementally as the player guesses, so the report is
    // (almost) ready by game-over. Daily/archive only. Calls are serialised on
    // `reporterQueue` and made in guess order.
    private var liveReporter: IncrementalSolveReporter?
    private let reporterQueue = DispatchQueue(label: "com.octordle.solveReporter", qos: .userInitiated)

    // MARK: - Timer

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var currentGuess: String {
        gameState.currentGuess
    }

    var guessCount: Int {
        gameState.guessCount
    }

    var remainingGuesses: Int {
        gameState.remainingGuesses
    }

    var maxGuesses: Int {
        gameState.maxGuesses
    }

    var isGameOver: Bool {
        gameState.isGameOver
    }

    /// True when replaying a daily that was already completed earlier today. Used to
    /// hide Share and to keep the first play's result/report as the canonical one.
    var isDailyReplay: Bool {
        gameState.mode == .daily && isPlayedDayCompleted
    }

    var boards: [BoardData] {
        gameState.boards
    }

    var combinedLetterStates: [Character: LetterState] {
        gameState.getCombinedLetterStates()
    }

    var perBoardLetterStates: [Character: KeyColorStates] {
        // Always show every board's state on the keyboard, regardless of scroll position.
        gameState.getPerBoardLetterStates()
    }

    /// The board count the keyboard splits each key into (2 halves, 4 quadrants, or 8 cells).
    var keyboardBoardCount: Int {
        boardCount
    }

    var boardCount: Int {
        gameState.difficulty.boardCount
    }

    /// The day string this puzzle belongs to (daily/archive); nil for practice/unlimited.
    private var playedDay: String? { gameState.dailyDate }

    /// Whether this daily/archive puzzle's day was already completed before this session.
    private var isPlayedDayCompleted: Bool {
        guard let day = playedDay else { return false }
        return dailyPuzzleService.completedDates.contains(day)
    }

    // MARK: - Initialization

    /// Which category puzzle this game is playing, if any (categories mode only) —
    /// used to record pack progress on a win.
    private var categoryContext: (categoryId: String, puzzleIndex: Int)?

    /// The pack id when this is a category game (for the How-to-Play card).
    var currentCategoryId: String? { categoryContext?.categoryId }

    /// Create a new game
    init(mode: GameMode, difficulty: Difficulty) {
        let words: [String]
        let boardCount = difficulty.boardCount
        if mode == .daily {
            words = wordService.getDailyWords(count: boardCount)
        } else {
            words = wordService.getRandomWords(count: boardCount)
        }

        self.gameState = GameState(mode: mode, difficulty: difficulty, words: words)
        startTimer()
        AnalyticsService.logGameStart(mode: mode, difficulty: difficulty)

        #if DEBUG
        print("🟡 [DEBUG] Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif

        startLiveReporterIfNeeded()
    }

    /// Create a category puzzle game with the pack's fixed 8-word set
    init(category: WordCategory, puzzleIndex: Int, difficulty: Difficulty = Constants.Game.defaultDifficulty) {
        let words = Array(category.puzzles[puzzleIndex].prefix(difficulty.boardCount))
        self.categoryContext = (category.id, puzzleIndex)

        self.gameState = GameState(mode: .categories, difficulty: difficulty, words: words)
        startTimer()
        AnalyticsService.logGameStart(mode: .categories, difficulty: difficulty)

        #if DEBUG
        print("🟡 [DEBUG] Category \(category.id) #\(puzzleIndex + 1) — Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif

        startLiveReporterIfNeeded()
    }

    /// Create a new archive game for a past daily date
    init(archiveDate: Date, difficulty: Difficulty = Constants.Game.defaultDifficulty) {
        let boardCount = difficulty.boardCount
        let words = wordService.getDailyWords(for: archiveDate, count: boardCount)

        self.gameState = GameState(mode: .daily, difficulty: difficulty, words: words, date: archiveDate)
        startTimer()
        AnalyticsService.logGameStart(mode: .daily, difficulty: difficulty, isArchive: gameState.isArchive)

        #if DEBUG
        print("🟡 [DEBUG] Archive \(GameState.dateString(for: archiveDate)) — Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif

        startLiveReporterIfNeeded()
    }

    /// Resume an existing game
    init(resuming state: GameState) {
        self.gameState = state
        // Reset session start time — accumulatedTime already has previous sessions
        self.gameState.startTime = Date()
        if !state.isGameOver {
            startTimer()
        }

        #if DEBUG
        let words = state.boards.map { $0.targetWord }
        print("🟡 [DEBUG] Resumed — Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif

        startLiveReporterIfNeeded()
    }

    /// Create a Challenge round: an 8-board Unlimited-style game whose result
    /// reports into an active `ChallengeSession` instead of being recorded. Like
    /// Unlimited, Challenge rounds are pure practice — no stats, achievements,
    /// themes, or review prompts (see the `challengeSession` branch in `endGame()`).
    init(challenge session: ChallengeSession) {
        let difficulty = Constants.Game.defaultDifficulty
        let words = wordService.getRandomWords(count: difficulty.boardCount)
        self.challengeSession = session

        // Run rounds tighten the guess budget so lives actually deplete; Timed
        // rounds keep the standard budget.
        let guessLimit: Int? = session.preset.family == .run ? ChallengeType.runGuessesPerRound : nil
        self.gameState = GameState(mode: .unlimited, difficulty: difficulty, words: words, maxGuesses: guessLimit)
        startTimer()
        AnalyticsService.logGameStart(mode: .unlimited, difficulty: difficulty)

        #if DEBUG
        print("🟡 [DEBUG] Challenge (\(session.preset.name)) — Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif

        startLiveReporterIfNeeded()

        // Force-finish the round the instant the shared clock hits zero, even if
        // the player is mid-guess.
        session.$timeExpired
            .filter { $0 }
            .sink { [weak self] _ in
                self?.forceFinishForChallenge()
            }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Timer Management

    private func startTimer() {
        updateTimeString()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeString()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimeString() {
        clock.text = gameState.elapsedTimeString
    }

    /// Pause the timer and save state (call on exit or background)
    func pauseGame() {
        guard timer != nil, !gameState.isGameOver else { return }
        // Accumulate current session time
        gameState.accumulatedTime += Date().timeIntervalSince(gameState.startTime)
        stopTimer()
        // Save daily state so progress is preserved
        if gameState.mode == .daily {
            statsService.saveDailyState(gameState)
        }
    }

    /// Resume the timer (call on re-enter or foreground)
    func resumeGame() {
        guard timer == nil, !gameState.isGameOver else { return }
        gameState.startTime = Date() // new session starts now
        startTimer()
    }

    // MARK: - Input Handling

    /// Add a letter to current guess
    func addLetter(_ letter: String) {
        guard !gameState.isGameOver else { return }
        guard gameState.currentGuess.count < 5 else { return }

        gameState.currentGuess += letter.uppercased()
        HapticManager.shared.keyTap()
    }

    /// Remove last letter from current guess
    func removeLetter() {
        guard !gameState.isGameOver else { return }
        guard !gameState.currentGuess.isEmpty else { return }

        gameState.currentGuess.removeLast()
        HapticManager.shared.deleteTap()
    }

    /// Submit current guess
    func submitGuess() {
        guard !gameState.isGameOver else { return }
        guard gameState.currentGuess.count == 5 else {
            showNotEnoughLetters()
            return
        }

        // Validate word
        guard wordService.isValidWord(gameState.currentGuess) else {
            AnalyticsService.logInvalidWordAttempt(word: gameState.currentGuess, difficulty: gameState.difficulty)
            showInvalidWord("Not in word list")
            return
        }

        HapticManager.shared.submitGuess()

        // Apply guess to all unsolved boards
        let guess = gameState.currentGuess

        for i in 0..<gameState.boards.count {
            if !gameState.boards[i].isSolved {
                let wasSolved = gameState.boards[i].isSolved
                _ = gameState.boards[i].evaluateGuess(guess)
                if !wasSolved && gameState.boards[i].isSolved {
                    HapticManager.shared.boardSolved()
                }
            }
        }

        // Update game state
        gameState.guessCount += 1
        gameState.currentGuess = ""

        // Feed this completed guess to the live Solve Report builder, in order, so
        // most of the analysis is done by the time the game ends.
        if let reporter = liveReporter {
            reporterQueue.async { reporter.ingest(guess: guess) }
        }

        // Check for game over
        if gameState.shouldEndGame {
            endGame()
            return
        }

        // Save daily state (snapshot with up-to-date accumulated time)
        if gameState.mode == .daily {
            var stateToSave = gameState
            stateToSave.accumulatedTime += Date().timeIntervalSince(stateToSave.startTime)
            statsService.saveDailyState(stateToSave)
        }
    }

    #if DEBUG
    /// TEMPORARY QA helper: pretends the player already played the last 2 days, then
    /// solves the first 6 boards with their real answers and finishes the game. This
    /// makes today the 3rd consecutive day (unlocks On a Roll + the Sky streak theme
    /// card) and solves 6 boards (First Word + Sharp Eye + review). Tests the full
    /// achievement/theme/review flow in one go. Remove this and its caller when done.
    /// Master switch for the QA auto-play. Flip to `true` to reactivate.
    static var debugAutoPlayEnabled = false

    func debugAutoPlay() {
        guard Self.debugAutoPlayEnabled else { return }
        guard gameState.guessCount == 0, !gameState.isGameOver else { return }
        if gameState.mode == .daily {
            dailyPuzzleService.debugSeedConsecutiveDaysBeforeToday(2)
        }
        let answers = gameState.boards.prefix(6).map { $0.targetWord }
        let filler = gameState.boards.first?.targetWord ?? "HAPPY"
        var script = Array(answers)
        while script.count < gameState.maxGuesses { script.append(filler) }
        for word in script {
            if gameState.isGameOver { break }
            gameState.currentGuess = word
            submitGuess()
        }
    }

    // TEMPORARY DEBUG: auto-solve every board and finish the game, so the achievement
    // unlock flow (incl. the new Explore-mode badges) can be tested without playing.
    // Triggered 3s after the game screen appears. Remove this method + its caller in
    // GameView.onAppear when done.
    static var debugAutoWinEnabled = false

    func debugAutoWin() {
        guard Self.debugAutoWinEnabled else { return }
        guard !gameState.isGameOver else { return }
        for word in gameState.boards.map({ $0.targetWord }) {
            if gameState.isGameOver { break }
            gameState.currentGuess = word
            submitGuess()
        }
    }
    #endif

    // MARK: - Game End

    private func endGame() {
        // Clear notepad
        isNotepadOpen = false
        notepadText = ""

        // Accumulate current session time before ending
        gameState.accumulatedTime += Date().timeIntervalSince(gameState.startTime)
        gameState.isGameOver = true
        gameState.isWon = gameState.allBoardsSolved
        gameState.endTime = Date()
        stopTimer()

        // Haptic feedback
        if gameState.isWon {
            // Check for perfect game (4 boards solved in 4 guesses = minimum possible)
            let minGuessesNeeded = gameState.difficulty.boardCount
            if gameState.guessCount <= minGuessesNeeded {
                HapticManager.shared.perfectGame()
            } else {
                HapticManager.shared.gameWon()
            }
        } else {
            HapticManager.shared.gameLost()
        }

        // Challenge rounds never reach the normal result flow — report the round
        // to the session and either queue the next round or leave the final board
        // on screen for the parent ChallengeGameView's end overlay.
        if let session = challengeSession {
            AnalyticsService.logGameComplete(gameState: gameState)
            session.reportRoundEnd(boards: gameState.boards)
            // Timed rounds flow continuously — auto-deal the next game after a beat.
            // Run rounds pause on a per-round result card; ChallengeGameView deals
            // the next round when the player taps Continue (by bumping roundEpoch).
            if !session.isOver && session.preset.family == .timed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self, let session = self.challengeSession, !session.isOver else { return }
                    // The clock can hit zero during this inter-round pause; the
                    // expiry signal would be swallowed (no round is in progress),
                    // so settle the session here instead of dealing a dead round.
                    if session.remainingSeconds <= 0 {
                        session.finish()
                    } else {
                        self.resetGame()
                    }
                }
            }
            return
        }

        // Only the daily challenge feeds stats, achievements, themes, and reviews.
        // Unlimited is pure practice and leaves no trace on The Record.
        // (Daily replays are also excluded to avoid inflating wins/streaks.)
        let shouldRecord = gameState.mode == .daily && !isPlayedDayCompleted

        var reviewTriggers: [ReviewManager.ReviewTrigger] = []

        if shouldRecord {
            // Snapshot the "happy moment" signals before recording so we can tell
            // whether this game just crossed a milestone (see ReviewManager).
            let preDailyChallengesCompleted = statsService.dailyChallengesCompleted
            let preBestBoardsSolved = statsService.bestBoardsSolvedInOneGame
            let preFastestWin = statsService.fastestWin
            let preTotalGamesPlayed = statsService.totalGamesPlayed

            // Snapshot theme unlock state before recording result
            let previouslyUnlocked = Set(BoardTheme.allCases.filter {
                $0.isUnlocked(isPremium: false, wordsSolved: statsService.totalWordsSolved, maxStreak: statsService.maxStreak)
            })

            // Record result (this updates wins/streaks) and capture any newly
            // unlocked achievements so the game screen can show unlock cards.
            let result = GameResult(from: gameState)
            newlyUnlockedAchievements = statsService.addResult(result)

            // Check for newly unlocked themes
            let nowUnlocked = Set(BoardTheme.allCases.filter {
                $0.isUnlocked(isPremium: false, wordsSolved: statsService.totalWordsSolved, maxStreak: statsService.maxStreak)
            })
            let freshlyUnlocked = nowUnlocked.subtracting(previouslyUnlocked)
            if let theme = freshlyUnlocked.first {
                newlyUnlockedTheme = theme
            }

            // Any achievement unlock except the very-first-solve one is a good
            // moment to ask for a review.
            if newlyUnlockedAchievements.contains(where: { !ReviewManager.excludedAchievementTriggers.contains($0) }) {
                reviewTriggers.append(.achievement)
            }

            // Daily-dedication milestones — crossed today for the first time.
            let postDailyChallengesCompleted = statsService.dailyChallengesCompleted
            let dailyMilestones = [5, 15, 40, 80]
            if dailyMilestones.contains(where: { preDailyChallengesCompleted < $0 && postDailyChallengesCompleted >= $0 }) {
                reviewTriggers.append(.dailyMilestone)
            }

            // Personal bests — only once the player has enough games under their
            // belt that this isn't just early-game noise.
            if preTotalGamesPlayed >= 10 {
                let postBestBoardsSolved = statsService.bestBoardsSolvedInOneGame
                let bestBoardsImproved = postBestBoardsSolved > preBestBoardsSolved && postBestBoardsSolved >= 4

                let postFastestWin = statsService.fastestWin
                let fastestWinImproved: Bool = {
                    guard let pre = preFastestWin, let post = postFastestWin else { return false }
                    return post < pre
                }()

                if bestBoardsImproved || fastestWinImproved {
                    reviewTriggers.append(.personalBest)
                }
            }

            // A 3-star win is a peak-happiness moment worth asking at — repeatable,
            // since ReviewManager's own cooldown keeps this from becoming spam.
            if result.isWon && result.starRating == 3 {
                reviewTriggers.append(.perfectWin)
            }

            // Crossing a day-streak milestone is the strongest happy moment in a
            // daily game. `streakIncludingToday` counts today (it's not marked
            // completed until the result sheet closes), and this path runs once
            // per day (first daily completion only), so an exact match means the
            // milestone was crossed today. Win-only: never ask on a loss.
            let streakMilestones: Set<Int> = [7, 30, 100]
            if result.isWon && streakMilestones.contains(DailyPuzzleService.shared.streakIncludingToday) {
                reviewTriggers.append(.streakMilestone)
            }
        }

        // Log analytics
        AnalyticsService.logGameComplete(gameState: gameState)

        // Save daily result (but DON'T mark as completed yet — that would trigger
        // DailyView to switch views and dismiss GameView before result sheet appears)
        if gameState.mode == .daily {
            // Save completed result for review (only first attempt, not replays)
            if !isPlayedDayCompleted {
                statsService.saveCompletedDailyResult(gameState)

                // Submit to the Daily Rank leaderboard — today's edition only, first
                // completion only, so replays and archive days never pollute it.
                if gameState.dailyDate == GameState.todayString() {
                    let solved = gameState.boards.filter { $0.isSolved }.count
                    let guesses = gameState.guessCount
                    let maxGuesses = gameState.maxGuesses
                    let seconds = gameState.elapsedSeconds
                    Task {
                        await GameCenterService.shared.submitDailyScore(
                            solvedBoards: solved,
                            guessCount: guesses,
                            maxGuesses: maxGuesses,
                            elapsedSeconds: seconds
                        )
                    }
                }
            }
            if let day = playedDay {
                statsService.clearDailyState(for: day)
            }
        }

        // Ask for a review only at a positive milestone (see ReviewManager).
        ReviewManager.shared.considerPrompt(triggers: reviewTriggers)

        // Categories mode keeps no stats, but a win completes the pack puzzle and
        // may unlock Explore-mode achievements — surfaced through the same unlock
        // cards as daily (the result sheet's onDismiss shows newlyUnlockedAchievements).
        if gameState.mode == .categories, gameState.isWon, let ctx = categoryContext {
            CategoryService.shared.markCompleted(categoryId: ctx.categoryId, puzzleIndex: ctx.puzzleIndex)
            newlyUnlockedAchievements = statsService.evaluateSpecialAchievements()
        }

        // Pre-compute the solve report in the background so it's ready the moment the
        // player opens it. Daily/archive only — Unlimited has no report.
        if gameState.mode == .daily {
            ensureSolveReport()
        }

        // Show result sheet after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showGameCompleteSheet = true
        }
    }

    // MARK: - Solve Report

    /// Start the incremental Solve Report builder for a live daily/archive game, and
    /// replay any guesses already made (resumed game) so it's caught up.
    private func startLiveReporterIfNeeded() {
        guard liveReporter == nil, gameState.mode == .daily, !gameState.isGameOver else { return }
        let targets = gameState.boards.map { $0.targetWord }
        let pool = wordService.solutionPool()
        let reporter = IncrementalSolveReporter(boardTargets: targets, pool: pool)
        liveReporter = reporter

        let existingRows = (gameState.boards.max(by: { $0.guesses.count < $1.guesses.count })?.guesses ?? [])
            .map { row in row.map { $0.letter }.joined() }
        if !existingRows.isEmpty {
            reporterQueue.async { existingRows.forEach { reporter.ingest(guess: $0) } }
        }
    }

    /// Make sure `solveReport` is populated. Computed at most once per puzzle:
    ///  1. in-memory cache (`solveReport`) — same game session;
    ///  2. on-disk cache keyed by day (daily/archive) — survives leaving the game,
    ///     re-opening from the result card, and app restarts.
    /// Daily puzzles are one-per-day with no replay, so the day key is unambiguous.
    func ensureSolveReport() {
        guard solveReport == nil, !isComputingSolveReport, gameState.isGameOver else { return }

        let day = gameState.mode == .daily ? gameState.dailyDate : nil

        // Standalone viewer (no live game, e.g. the daily screen): show the cached
        // first-play report. Live games always use their own result (below), so a
        // replay shows the replay's analysis, not the original day's.
        if liveReporter == nil, let day, let cached = statsService.loadSolveReport(for: day) {
            solveReport = cached
            return
        }

        isComputingSolveReport = true
        let state = gameState

        if let reporter = liveReporter {
            // Incremental path: turns were analysed during play. finish() runs on the
            // same serial queue, so it lands after every ingest() — near-instant.
            // Persist only the first play so the daily screen keeps showing the original.
            let persist = (day != nil) && !isPlayedDayCompleted
            reporterQueue.async { [weak self] in
                let result = reporter.finish(gameState: state)
                DispatchQueue.main.async {
                    self?.solveReport = result
                    self?.isComputingSolveReport = false
                    if persist, let day { self?.statsService.saveSolveReport(result, for: day) }
                }
            }
        } else {
            // Standalone cache miss: one-shot analysis of the saved result.
            let pool = WordService.shared.solutionPool()
            Task.detached(priority: .userInitiated) {
                let result = SolveAnalyzer.analyze(gameState: state, pool: pool)
                await MainActor.run {
                    self.solveReport = result
                    self.isComputingSolveReport = false
                    if let day { self.statsService.saveSolveReport(result, for: day) }
                }
            }
        }
    }

    // MARK: - Invalid Word Handling

    private func showNotEnoughLetters() {
        invalidWordMessage = "Not enough letters"
        showInvalidWordAlert = true
        HapticManager.shared.notEnoughLetters()

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showInvalidWordAlert = false
        }
    }

    private func showInvalidWord(_ message: String) {
        invalidWordMessage = message
        showInvalidWordAlert = true
        HapticManager.shared.invalidWord()

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showInvalidWordAlert = false
        }
    }

    /// Mark daily/archive as completed (call after result sheet is dismissed)
    func markDailyCompletedIfNeeded() {
        if gameState.mode == .daily, let day = playedDay {
            dailyPuzzleService.markCompleted(day)
        }
    }

    /// Force-ends the current round for a Challenge session — used when the shared
    /// clock/lives run out mid-game (e.g. the timed clock hits zero while still
    /// guessing). Stops further input immediately, then reports boards solved so
    /// far exactly like a natural round end.
    func forceFinishForChallenge() {
        guard challengeSession != nil, !gameState.isGameOver else { return }
        endGame()
    }

    // MARK: - State Management

    /// Load a saved game state
    func loadState(_ state: GameState) {
        stopTimer()
        self.gameState = state
        startTimer()
    }

    /// Reset game for replay
    func resetGame() {
        stopTimer()
        let words: [String]
        let boardCount = gameState.difficulty.boardCount
        switch gameState.mode {
        case .daily:
            words = wordService.getDailyWords(count: boardCount)
        case .categories:
            // A category puzzle is a fixed set — replaying means the same words.
            words = gameState.boards.map { $0.targetWord }
        case .practice, .unlimited:
            words = wordService.getRandomWords(count: boardCount)
        }
        self.gameState = GameState(mode: gameState.mode, difficulty: gameState.difficulty, words: words)
        showGameCompleteSheet = false
        startTimer()
        AnalyticsService.logGameStart(mode: gameState.mode, difficulty: gameState.difficulty)
    }

    // MARK: - Sharing

    func shareText() -> String {
        gameState.generateShareText()
    }

    func emojiGrid() -> String {
        gameState.generateEmojiGrid()
    }
}

/// The in-game count-up clock, kept out of `GameViewModel` so its per-second
/// update only redraws the label that shows it (see `GameTimerLabel`).
@MainActor
final class GameClock: ObservableObject {
    @Published var text = "0:00"
}
