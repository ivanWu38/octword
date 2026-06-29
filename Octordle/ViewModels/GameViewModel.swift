import SwiftUI
import Combine

/// Main game view model
@MainActor
class GameViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var gameState: GameState
    @Published var showInvalidWordAlert = false
    @Published var showGameCompleteSheet = false
    @Published var elapsedTimeString = "0:00"
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

    // MARK: - Services

    private let wordService = WordService.shared
    private let statsService = StatsService.shared
    private let dailyPuzzleService = DailyPuzzleService.shared

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
        gameState.difficulty.maxGuesses
    }

    var isGameOver: Bool {
        gameState.isGameOver
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
    }

    /// Create a new archive game for a past daily date
    init(archiveDate: Date, difficulty: Difficulty = Constants.Game.defaultDifficulty) {
        let boardCount = difficulty.boardCount
        let words = wordService.getDailyWords(for: archiveDate, count: boardCount)

        self.gameState = GameState(mode: .daily, difficulty: difficulty, words: words, date: archiveDate)
        startTimer()
        AnalyticsService.logGameStart(mode: .daily, difficulty: difficulty)

        #if DEBUG
        print("🟡 [DEBUG] Archive \(GameState.dateString(for: archiveDate)) — Answers: \(words.enumerated().map { "Board \($0.offset + 1): \($0.element)" }.joined(separator: ", "))")
        #endif
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
        elapsedTimeString = gameState.elapsedTimeString
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
        while script.count < gameState.difficulty.maxGuesses { script.append(filler) }
        for word in script {
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

        // Only the daily challenge feeds stats, achievements, themes, and reviews.
        // Unlimited is pure practice and leaves no trace on The Record.
        // (Daily replays are also excluded to avoid inflating wins/streaks.)
        let shouldRecord = gameState.mode == .daily && !isPlayedDayCompleted

        if shouldRecord {
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
        }

        // Log analytics
        AnalyticsService.logGameComplete(gameState: gameState)

        // Save daily result (but DON'T mark as completed yet — that would trigger
        // DailyView to switch views and dismiss GameView before result sheet appears)
        if gameState.mode == .daily {
            // Save completed result for review (only first attempt, not replays)
            if !isPlayedDayCompleted {
                statsService.saveCompletedDailyResult(gameState)
            }
            if let day = playedDay {
                statsService.clearDailyState(for: day)
            }
        }

        // Ask for a review only at a positive milestone (see ReviewManager).
        ReviewManager.shared.considerPrompt(forNewlyUnlocked: newlyUnlockedAchievements)

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

    /// Make sure `solveReport` is populated. Computed at most once per puzzle:
    ///  1. in-memory cache (`solveReport`) — same game session;
    ///  2. on-disk cache keyed by day (daily/archive) — survives leaving the game,
    ///     re-opening from the result card, and app restarts.
    /// Daily puzzles are one-per-day with no replay, so the day key is unambiguous.
    func ensureSolveReport() {
        guard solveReport == nil, !isComputingSolveReport, gameState.isGameOver else { return }

        let day = gameState.mode == .daily ? gameState.dailyDate : nil
        if let day, let cached = statsService.loadSolveReport(for: day) {
            solveReport = cached
            return
        }

        isComputingSolveReport = true
        let pool = WordService.shared.solutionPool()
        let state = gameState
        Task.detached(priority: .userInitiated) {
            let result = SolveAnalyzer.analyze(gameState: state, pool: pool)
            await MainActor.run {
                self.solveReport = result
                self.isComputingSolveReport = false
                if let day { self.statsService.saveSolveReport(result, for: day) }
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
        if gameState.mode == .daily {
            words = wordService.getDailyWords(count: boardCount)
        } else {
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
