import Foundation

/// Statistics service for tracking game history
@MainActor
class StatsService: ObservableObject {
    static let shared = StatsService()

    private let defaults = UserDefaults.standard
    private let resultsKey = "octordle_gameResults"
    private let achievementsKey = "octordle_achievements"
    private let dailyStateKey = "octordle_dailyState"
    private let completedDailyResultKey = "octordle_completedDailyResult"

    @Published private(set) var gameResults: [GameResult] = []
    @Published private(set) var achievementProgress = AchievementProgress()

    private init() {
        loadResults()
        loadAchievements()
    }

    // MARK: - Statistics Properties

    var totalGamesPlayed: Int {
        gameResults.count
    }

    var totalWins: Int {
        gameResults.filter { $0.isWon }.count
    }

    var winPercentage: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalGamesPlayed) * 100
    }

    var currentStreak: Int {
        DailyPuzzleService.shared.currentStreak
    }

    var maxStreak: Int {
        max(achievementProgress.maxStreak, DailyPuzzleService.shared.currentStreak)
    }

    var averageGuesses: Double {
        let wins = gameResults.filter { $0.isWon }
        guard !wins.isEmpty else { return 0 }
        return Double(wins.reduce(0) { $0 + $1.guessCount }) / Double(wins.count)
    }

    var averageTime: Int {
        let wins = gameResults.filter { $0.isWon }
        guard !wins.isEmpty else { return 0 }
        return wins.reduce(0) { $0 + $1.elapsedSeconds } / wins.count
    }

    var threeStarCount: Int {
        gameResults.filter { $0.starRating == 3 }.count
    }

    var twoStarCount: Int {
        gameResults.filter { $0.starRating == 2 }.count
    }

    var oneStarCount: Int {
        gameResults.filter { $0.starRating == 1 }.count
    }

    // MARK: - Game Result Management

    /// Records a result and returns any achievements unlocked by it
    /// (sorted in display order), so the game screen can present unlock cards.
    @discardableResult
    func addResult(_ result: GameResult) -> [Achievement] {
        gameResults.insert(result, at: 0)
        saveResults()
        return updateAchievements(for: result)
    }

    // MARK: - Daily State Management
    //
    // Daily *and* archive games are mode == .daily; they're disambiguated by their
    // `dailyDate`. State and completed results are therefore keyed per day so an
    // in-progress archive game never overwrites today's puzzle. The original
    // single-slot keys are kept in sync for *today* for backward compatibility.

    private func stateKey(for day: String) -> String { "\(dailyStateKey)_\(day)" }
    private func resultKey(for day: String) -> String { "\(completedDailyResultKey)_\(day)" }

    func saveDailyState(_ state: GameState) {
        guard state.mode == .daily, let day = state.dailyDate else { return }
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: stateKey(for: day))
            if day == GameState.todayString() {
                defaults.set(encoded, forKey: dailyStateKey) // legacy
            }
        }
    }

    func loadDailyState() -> GameState? {
        loadDailyState(for: GameState.todayString())
    }

    func loadDailyState(for day: String) -> GameState? {
        // Prefer the per-day key; fall back to the legacy single slot for today.
        let data = defaults.data(forKey: stateKey(for: day))
            ?? (day == GameState.todayString() ? defaults.data(forKey: dailyStateKey) : nil)
        guard let data,
              let state = try? JSONDecoder().decode(GameState.self, from: data),
              state.dailyDate == day else {
            clearDailyState(for: day)
            return nil
        }
        return state
    }

    func clearDailyState() {
        clearDailyState(for: GameState.todayString())
    }

    func clearDailyState(for day: String) {
        defaults.removeObject(forKey: stateKey(for: day))
        if day == GameState.todayString() {
            defaults.removeObject(forKey: dailyStateKey) // legacy
        }
    }

    // MARK: - Completed Daily Result (for review)

    func saveCompletedDailyResult(_ state: GameState) {
        guard state.mode == .daily, let day = state.dailyDate else { return }
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: resultKey(for: day))
            if day == GameState.todayString() {
                defaults.set(encoded, forKey: completedDailyResultKey) // legacy
            }
        }
    }

    func loadCompletedDailyResult() -> GameState? {
        if let state = loadCompletedDailyResult(for: GameState.todayString()) {
            return state
        }
        // Fallback: reconstruct today's result from the GameResult summary.
        let today = Calendar.current.startOfDay(for: Date())
        if let result = gameResults.first(where: { $0.mode == .daily && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return GameState(from: result)
        }
        return nil
    }

    func loadCompletedDailyResult(for day: String) -> GameState? {
        if let data = defaults.data(forKey: resultKey(for: day)),
           let state = try? JSONDecoder().decode(GameState.self, from: data) {
            return state
        }
        // Legacy single-slot key (kept in sync for today only).
        if day == GameState.todayString(),
           let data = defaults.data(forKey: completedDailyResultKey),
           let state = try? JSONDecoder().decode(GameState.self, from: data),
           state.dailyDate == day {
            return state
        }
        return nil
    }

    // MARK: - Solve Report (cached per day so it's computed only once)

    private func solveReportKey(for day: String) -> String { "octordle_solveReport_\(day)" }

    func saveSolveReport(_ report: SolveReport, for day: String) {
        if let encoded = try? JSONEncoder().encode(report) {
            defaults.set(encoded, forKey: solveReportKey(for: day))
        }
    }

    func loadSolveReport(for day: String) -> SolveReport? {
        guard let data = defaults.data(forKey: solveReportKey(for: day)) else { return nil }
        return try? JSONDecoder().decode(SolveReport.self, from: data)
    }

    // MARK: - Persistence

    private func loadResults() {
        guard let data = defaults.data(forKey: resultsKey) else { return }
        do {
            self.gameResults = try JSONDecoder().decode([GameResult].self, from: data)
        } catch {
            // Backup raw data so future versions can recover
            defaults.set(data, forKey: resultsKey + "_backup")
            print("[StatsService] Failed to decode gameResults: \(error)")
        }
    }

    private func saveResults() {
        if let encoded = try? JSONEncoder().encode(gameResults) {
            defaults.set(encoded, forKey: resultsKey)
        }
    }

    private func loadAchievements() {
        guard let data = defaults.data(forKey: achievementsKey) else { return }
        do {
            self.achievementProgress = try JSONDecoder().decode(AchievementProgress.self, from: data)
        } catch {
            defaults.set(data, forKey: achievementsKey + "_backup")
            print("[StatsService] Failed to decode achievements: \(error)")
        }
    }

    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievementProgress) {
            defaults.set(encoded, forKey: achievementsKey)
        }
    }

    // MARK: - Achievement Updates

    /// Evaluates achievements after a result and returns the ones newly unlocked
    /// (in display order). The unlock card on the game screen fires the haptic now,
    /// so we no longer buzz here for generic unlocks.
    @discardableResult
    private func updateAchievements(for result: GameResult) -> [Achievement] {
        let previousUnlockedSet = achievementProgress.unlockedAchievements
        var unlocked = achievementProgress.unlockedAchievements

        // Day-based streak (consecutive days played, win or lose). For a daily we
        // use the streak that *includes today* — today isn't marked completed until
        // the result sheet closes, which is after this runs — so streak rewards fire
        // on the correct day instead of one day late.
        let dailyStreak = result.mode == .daily
            ? DailyPuzzleService.shared.streakIncludingToday
            : DailyPuzzleService.shared.currentStreak
        achievementProgress.maxStreak = max(achievementProgress.maxStreak, dailyStreak)

        // Words solved — cumulative, counts boards solved even in losing games
        let words = totalWordsSolved
        if words >= 1 { unlocked.insert(.firstWord) }
        if words >= Achievement.wordCollector.requirement { unlocked.insert(.wordCollector) }
        if words >= Achievement.wordWizard.requirement { unlocked.insert(.wordWizard) }
        if words >= Achievement.lexiconMaster.requirement { unlocked.insert(.lexiconMaster) }

        // Full win — all 8 boards in one game
        if result.isWon { unlocked.insert(.fullHouse) }

        // Standout round — solved most of the boards even if not a full win
        let solvedThisGame = result.boardResults.filter { $0.isSolved }.count
        if solvedThisGame >= Achievement.sharpEye.requirement { unlocked.insert(.sharpEye) }

        // Clutch finish — won using the very last guess
        if result.isWon && result.guessCount == result.difficulty.maxGuesses {
            unlocked.insert(.downToTheWire)
        }

        // Flawless — a 3-star win
        if result.isWon && result.starRating == 3 { unlocked.insert(.flawless) }

        // Play streak milestones
        if dailyStreak >= 3 { unlocked.insert(.streak3) }
        if dailyStreak >= 7 { unlocked.insert(.streak7) }
        if dailyStreak >= 30 { unlocked.insert(.streak30) }

        // Daily dedication
        if result.mode == .daily {
            let dailies = dailyChallengesCompleted
            if dailies >= Achievement.explorer.requirement { unlocked.insert(.explorer) }
            if dailies >= Achievement.dailyDevotee.requirement { unlocked.insert(.dailyDevotee) }
        }

        achievementProgress.unlockedAchievements = unlocked

        let newlyUnlocked = unlocked.subtracting(previousUnlockedSet)
        for achievement in newlyUnlocked {
            AnalyticsService.logAchievementUnlocked(achievement: achievement)
        }

        // Streak milestone haptic (separate from the unlock card)
        if dailyStreak == 7 || dailyStreak == 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                HapticManager.shared.streakMilestone()
            }
        }

        saveAchievements()

        // Return in display order so multiple cards appear in a sensible sequence
        return Achievement.allCases.filter { newlyUnlocked.contains($0) }
    }

    // MARK: - Stats by Difficulty

    func stats(for difficulty: Difficulty) -> (played: Int, won: Int, winRate: Double) {
        let filtered = gameResults.filter { $0.difficulty == difficulty }
        let won = filtered.filter { $0.isWon }.count
        let winRate = filtered.isEmpty ? 0 : Double(won) / Double(filtered.count) * 100
        return (filtered.count, won, winRate)
    }

    // MARK: - New Statistics (No Streak Pressure)

    /// Total words solved across all games
    var totalWordsSolved: Int {
        gameResults.reduce(0) { total, result in
            total + result.boardResults.filter { $0.isSolved }.count
        }
    }

    /// Total time enjoyed playing (in seconds)
    var totalTimeEnjoyed: Int {
        gameResults.reduce(0) { $0 + $1.elapsedSeconds }
    }

    /// Format total time as readable string
    var totalTimeEnjoyedString: String {
        let totalSeconds = totalTimeEnjoyed
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Best (fastest) time for a difficulty (wins only)
    func bestTime(for difficulty: Difficulty) -> Int? {
        let wins = gameResults.filter { $0.difficulty == difficulty && $0.isWon }
        return wins.map { $0.elapsedSeconds }.min()
    }

    /// Best (fewest) guesses for a difficulty (wins only)
    func bestGuesses(for difficulty: Difficulty) -> Int? {
        let wins = gameResults.filter { $0.difficulty == difficulty && $0.isWon }
        return wins.map { $0.guessCount }.min()
    }

    /// Format time in seconds to MM:SS
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    /// Most played difficulty
    var mostPlayedDifficulty: Difficulty? {
        let counts = Dictionary(grouping: gameResults, by: { $0.difficulty })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Daily challenges completed count
    var dailyChallengesCompleted: Int {
        gameResults.filter { $0.mode == .daily }.count
    }

    // MARK: - Engaging Statistics

    /// Guess distribution for won games (how many games won with X guesses)
    func guessDistribution(for difficulty: Difficulty? = nil) -> [Int: Int] {
        let wins: [GameResult]
        if let diff = difficulty {
            wins = gameResults.filter { $0.isWon && $0.difficulty == diff }
        } else {
            wins = gameResults.filter { $0.isWon }
        }

        var distribution: [Int: Int] = [:]
        for result in wins {
            distribution[result.guessCount, default: 0] += 1
        }
        return distribution
    }

    /// Fastest win time ever (in seconds)
    var fastestWin: Int? {
        gameResults.filter { $0.isWon }.map { $0.elapsedSeconds }.min()
    }

    /// Fastest win for a specific difficulty
    func fastestWin(for difficulty: Difficulty) -> Int? {
        gameResults.filter { $0.isWon && $0.difficulty == difficulty }
            .map { $0.elapsedSeconds }.min()
    }

    /// Number of clutch wins (won with last guess)
    var clutchWins: Int {
        gameResults.filter { result in
            guard result.isWon else { return false }
            return result.guessCount == result.difficulty.maxGuesses
        }.count
    }

    /// Number of perfect games (3 stars)
    var perfectGames: Int {
        gameResults.filter { $0.isWon && $0.starRating == 3 }.count
    }

    /// Games played this week
    var gamesThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return gameResults.filter { $0.date >= weekAgo }.count
    }

    /// Games won this week
    var winsThisWeek: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return gameResults.filter { $0.isWon && $0.date >= weekAgo }.count
    }

    /// Average guesses per win (formatted string)
    var averageGuessesString: String {
        let wins = gameResults.filter { $0.isWon }
        guard !wins.isEmpty else { return "-" }
        let avg = Double(wins.reduce(0) { $0 + $1.guessCount }) / Double(wins.count)
        return String(format: "%.1f", avg)
    }

    /// Win rate string
    var winRateString: String {
        guard totalGamesPlayed > 0 else { return "0%" }
        let rate = Double(totalWins) / Double(totalGamesPlayed) * 100
        return String(format: "%.0f%%", rate)
    }

    /// Achievement progress percentage
    var achievementProgressPercentage: Double {
        let total = Achievement.allCases.count
        let unlocked = achievementProgress.unlockedAchievements.count
        return Double(unlocked) / Double(total) * 100
    }

    /// Get progress for a specific achievement (returns current/required)
    func progressFor(_ achievement: Achievement) -> (current: Int, required: Int) {
        let required = achievement.requirement
        let current: Int

        switch achievement {
        case .firstWord, .wordCollector, .wordWizard, .lexiconMaster:
            current = min(totalWordsSolved, required)
        case .fullHouse:
            current = totalWins > 0 ? 1 : 0
        case .sharpEye:
            current = min(bestBoardsSolvedInOneGame, required)
        case .downToTheWire:
            current = clutchWins > 0 ? 1 : 0
        case .flawless:
            current = perfectGames > 0 ? 1 : 0
        case .streak3, .streak7, .streak30:
            current = min(achievementProgress.maxStreak, required)
        case .explorer, .dailyDevotee:
            current = min(dailyChallengesCompleted, required)
        case .onAssignment, .beatReporter, .specialEditions,
             .rollThePresses, .theLongHaul, .nervesOfSteel,
             .beatTheClock, .filedOnTime, .frontPageNews:
            current = min(specialCurrent(for: achievement), required)
        }

        return (current, required)
    }

    // MARK: - Special (Explore-mode) Achievements

    /// Live progress for a special achievement, read from CategoryService /
    /// ChallengeSession records rather than daily game results. Shared by
    /// `progressFor` (display) and `evaluateSpecialAchievements` (unlock check).
    private func specialCurrent(for achievement: Achievement) -> Int {
        switch achievement {
        case .onAssignment, .specialEditions:
            return CategoryService.shared.overallProgress.solved
        case .beatReporter:
            let anyPackCleared = CategoryService.shared.categories.contains { cat in
                cat.puzzleCount > 0
                    && CategoryService.shared.completedCount(categoryId: cat.id) == cat.puzzleCount
            }
            return anyPackCleared ? 1 : 0
        case .rollThePresses, .theLongHaul:
            // Longest survival across any Run preset.
            return ChallengeType.runPresets
                .map { ChallengeSession.loadBestRounds(for: $0.id) }.max() ?? 0
        case .nervesOfSteel:
            return ChallengeSession.loadBestRounds(for: ChallengeType.runSudden.id)
        case .beatTheClock:
            // Completed Flash = reached its 1-game target.
            return ChallengeSession.loadBestRounds(for: ChallengeType.timedQuick.id) >= ChallengeType.timedQuick.gameTarget ? 1 : 0
        case .filedOnTime:
            return ChallengeSession.loadBestRounds(for: ChallengeType.timedExtended.id) >= ChallengeType.timedExtended.gameTarget ? 1 : 0
        case .frontPageNews:
            return ChallengeSession.loadBestRounds(for: ChallengeType.timedUltra.id) >= ChallengeType.timedUltra.gameTarget ? 1 : 0
        default:
            return 0
        }
    }

    /// Re-evaluates every Explore-mode achievement from current records and returns
    /// the ones newly unlocked (display order). Call after a Categories win or when
    /// a Challenge session ends, so the game screen can present unlock cards.
    @discardableResult
    func evaluateSpecialAchievements() -> [Achievement] {
        let previous = achievementProgress.unlockedAchievements
        var unlocked = previous
        for achievement in Achievement.specialCases where specialCurrent(for: achievement) >= achievement.requirement {
            unlocked.insert(achievement)
        }
        let newly = unlocked.subtracting(previous)
        guard !newly.isEmpty else { return [] }

        achievementProgress.unlockedAchievements = unlocked
        for achievement in newly {
            AnalyticsService.logAchievementUnlocked(achievement: achievement)
        }
        saveAchievements()

        return Achievement.allCases.filter { newly.contains($0) }
    }

    /// Most boards solved in any single game (for the "Sharp Eye" achievement)
    var bestBoardsSolvedInOneGame: Int {
        gameResults.map { $0.boardResults.filter { $0.isSolved }.count }.max() ?? 0
    }

    /// Unlocked achievements count
    var unlockedAchievementsCount: Int {
        achievementProgress.unlockedAchievements.count
    }

    /// Total achievements count
    var totalAchievementsCount: Int {
        Achievement.allCases.count
    }

    /// Check if achievement is unlocked
    func isUnlocked(_ achievement: Achievement) -> Bool {
        achievementProgress.unlockedAchievements.contains(achievement)
    }
}
