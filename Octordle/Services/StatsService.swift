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

    func saveDailyState(_ state: GameState) {
        guard state.mode == .daily else { return }
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: dailyStateKey)
        }
    }

    func loadDailyState() -> GameState? {
        guard let data = defaults.data(forKey: dailyStateKey),
              let state = try? JSONDecoder().decode(GameState.self, from: data) else {
            return nil
        }

        // Check if it's today's puzzle
        if state.dailyDate == GameState.todayString() {
            return state
        }

        // Clear old daily state
        defaults.removeObject(forKey: dailyStateKey)
        return nil
    }

    func clearDailyState() {
        defaults.removeObject(forKey: dailyStateKey)
    }

    // MARK: - Completed Daily Result (for review)

    func saveCompletedDailyResult(_ state: GameState) {
        guard state.mode == .daily else { return }
        if let encoded = try? JSONEncoder().encode(state) {
            defaults.set(encoded, forKey: completedDailyResultKey)
        }
    }

    func loadCompletedDailyResult() -> GameState? {
        // Try full saved GameState first
        if let data = defaults.data(forKey: completedDailyResultKey),
           let state = try? JSONDecoder().decode(GameState.self, from: data),
           state.dailyDate == GameState.todayString() {
            return state
        }
        // Fallback: reconstruct from GameResult summary
        let today = Calendar.current.startOfDay(for: Date())
        if let result = gameResults.first(where: { $0.mode == .daily && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return GameState(from: result)
        }
        return nil
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

        // Day-based streak (consecutive days played, win or lose)
        let dailyStreak = DailyPuzzleService.shared.currentStreak
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
        }

        return (current, required)
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
