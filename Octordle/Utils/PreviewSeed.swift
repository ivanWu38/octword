import Foundation
import SwiftUI

/// 常駐的 DEBUG-only App Store 截圖 seed（app-store-previews skill）。整個型別包在 #if DEBUG，
/// release build 不含任何程式碼。由 simctl env 觸發（_design/shoot.sh 的 launch 會自動加 SIMCTL_CHILD_ 前綴）：
///
///   OCTORDLE_PREVIEW_SEED=1     開啟：跳過 onboarding / consent / ATT，不啟動廣告 SDK，寫入示範數據
///   OCTORDLE_SCREEN=game|today|rank|report|explore|challenges|categories|unlimited|journey
///                               直達該畫面（game = 今日題進行中；rank/report/today = 今日題已完成）
///   OCTORDLE_NO_ADS=1           藏掉遊戲畫面底部 banner（仍是免費狀態外觀）
///   OCTORDLE_APPEARANCE=dark|light|system
///   OCTORDLE_PREVIEW_RESET=1    先清掉 UserDefaults 再 seed（預設就會清，避免上一輪殘留）
///
/// 數字口徑：跟核可的 preview 文案一致；不得出現價格 / free（2.3.7）。
#if DEBUG
@MainActor
enum PreviewSeed {
    private static let env = ProcessInfo.processInfo.environment
    static var isOn: Bool { env["OCTORDLE_PREVIEW_SEED"] == "1" }
    static var screen: String? { isOn ? env["OCTORDLE_SCREEN"] : nil }
    static var noAds: Bool { isOn && env["OCTORDLE_NO_ADS"] == "1" }

    /// Which tab the requested screen lives on.
    static var tab: Octordle.Tab? {
        switch screen {
        case "game", "today", "rank", "report": return .today
        case "explore", "challenges", "categories": return .explore
        case "unlimited": return .unlimited
        case "journey": return .journey
        default: return nil
        }
    }

    /// Screens that need today's edition already solved.
    static var wantsTodayCompleted: Bool {
        ["today", "rank", "report", "journey"].contains(screen ?? "")
    }

    // MARK: - Daily Rank demo rows

    struct RankRow {
        let rank: Int
        let name: String
        let solved: Int
        let guesses: Int
        let seconds: Int
        let isLocal: Bool
        /// Same encoding as `GameCenterService.encodeScore` (inlined: that one is main-actor bound).
        var score: Int {
            let maxGuesses = Constants.Game.defaultDifficulty.maxGuesses
            return solved * 1_000_000 + max(0, maxGuesses - guesses) * 10_000 + max(0, 3600 - seconds)
        }
    }

    static let localRank = 7

    static let rankRows: [RankRow] = [
        RankRow(rank: 1, name: "Margot L.", solved: 8, guesses: 9, seconds: 252, isLocal: false),
        RankRow(rank: 2, name: "wordsmith_jo", solved: 8, guesses: 9, seconds: 311, isLocal: false),
        RankRow(rank: 3, name: "Tomasz K.", solved: 8, guesses: 10, seconds: 198, isLocal: false),
        RankRow(rank: 4, name: "Aiko", solved: 8, guesses: 10, seconds: 274, isLocal: false),
        RankRow(rank: 5, name: "Sam Okafor", solved: 8, guesses: 10, seconds: 402, isLocal: false),
        RankRow(rank: 6, name: "puzzlepete", solved: 8, guesses: 11, seconds: 233, isLocal: false),
        RankRow(rank: 7, name: "You", solved: 8, guesses: 11, seconds: 287, isLocal: true),
        RankRow(rank: 8, name: "Elena R.", solved: 8, guesses: 11, seconds: 356, isLocal: false),
        RankRow(rank: 9, name: "Dev Patel", solved: 8, guesses: 12, seconds: 301, isLocal: false),
        RankRow(rank: 10, name: "crossword_cat", solved: 8, guesses: 12, seconds: 447, isLocal: false),
        RankRow(rank: 11, name: "Hannah B.", solved: 8, guesses: 13, seconds: 380, isLocal: false),
        RankRow(rank: 12, name: "Luis M.", solved: 7, guesses: 13, seconds: 512, isLocal: false),
        RankRow(rank: 13, name: "Ines", solved: 7, guesses: 13, seconds: 640, isLocal: false),
        RankRow(rank: 14, name: "morningpages", solved: 6, guesses: 13, seconds: 421, isLocal: false),
    ]

    static var localRankRow: RankRow? { rankRows.first { $0.isLocal } }

    // MARK: - Apply

    /// Call once from RootView's `.task` when `isOn`. Clears the app's own UserDefaults
    /// (so reruns are deterministic), then writes demo data through the real services.
    static func applyIfRequested() {
        guard isOn else { return }
        resetDefaults()

        // Appearance
        if let a = env["OCTORDLE_APPEARANCE"], let pref = ColorSchemePreference(rawValue: a) {
            ThemeService.shared.colorSchemePreference = pref
        }

        // Quiet the one-off intros
        let d = UserDefaults.standard
        d.set(true, forKey: Constants.UserDefaultsKeys.hasSeenNotepadIntro)
        d.set(true, forKey: "hasSeenOnboarding")

        seedHistory()
        seedChallenges()
        seedCategories()

        if wantsTodayCompleted {
            seedTodayCompleted()
        }
        GameCenterService.shared.debugMarkAuthenticated()
    }

    /// Services are singletons that read UserDefaults in `init`, so wiping disk alone
    /// leaves stale in-memory state — reset both.
    private static func resetDefaults() {
        let d = UserDefaults.standard
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("octordle_") || key == "hasSeenOnboarding" {
            d.removeObject(forKey: key)
        }
        StatsService.shared.debugResetAll()
        DailyPuzzleService.shared.debugResetAll()
        CategoryService.shared.debugResetAll()
        StatsService.shared.clearDailyState()
    }

    /// 11 straight days before today (12 with today), plus enough wins for a lively Journey page.
    private static func seedHistory() {
        DailyPuzzleService.shared.debugSeedConsecutiveDaysBeforeToday(11)
        let stats = StatsService.shared
        let words = WordService.shared
        // 34 past editions: mostly full solves, a few 7/8 and 6/8.
        let outcomes: [(solved: Int, guesses: Int, seconds: Int)] = (0..<34).map { i in
            switch i % 9 {
            case 0: return (8, 9, 231)
            case 1: return (8, 11, 318)
            case 2: return (8, 10, 274)
            case 3: return (7, 13, 402)
            case 4: return (8, 12, 356)
            case 5: return (8, 10, 244)
            case 6: return (6, 13, 468)
            case 7: return (8, 11, 297)
            default: return (8, 12, 333)
            }
        }
        for (i, o) in outcomes.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -(i + 1), to: Date()) ?? Date()
            let targets = words.getDailyWords(for: date, count: Constants.Game.defaultDifficulty.boardCount)
            var state = GameState(mode: .daily, difficulty: Constants.Game.defaultDifficulty, words: targets, date: date)
            play(&state, solve: o.solved, guesses: o.guesses)
            state.accumulatedTime = TimeInterval(o.seconds)
            state.isGameOver = true
            state.isWon = state.allBoardsSolved
            state.endTime = Date()
            stats.addResult(GameResult(from: state))
        }
    }

    /// Solves `solve` boards using `guesses` total guesses: two openers, then the answers.
    private static func play(_ state: inout GameState, solve: Int, guesses: Int) {
        var script = ["SLATE", "CRONY"]
        let answers = state.boards.prefix(solve).map { $0.targetWord }
        script.append(contentsOf: answers)
        while script.count < guesses { script.insert("PRIMO", at: 2) }
        for word in script.prefix(state.maxGuesses) {
            for i in state.boards.indices where !state.boards[i].isSolved {
                _ = state.boards[i].evaluateGuess(word)
            }
            state.guessCount += 1
        }
    }

    /// Today's edition finished 8/8 in 11 guesses, 4:47 — matches the Daily Rank row.
    private static func seedTodayCompleted() {
        let words = WordService.shared.getDailyWords(count: Constants.Game.defaultDifficulty.boardCount)
        var state = GameState(mode: .daily, difficulty: Constants.Game.defaultDifficulty, words: words)
        play(&state, solve: 8, guesses: 11)
        state.accumulatedTime = 287
        state.isGameOver = true
        state.isWon = true
        state.endTime = Date()
        StatsService.shared.addResult(GameResult(from: state))
        StatsService.shared.saveCompletedDailyResult(state)
        DailyPuzzleService.shared.markTodayCompleted()
    }

    private static func seedChallenges() {
        let best: [String: Int] = [
            "timed_quick": 8, "timed_standard": 15, "timed_extended": 27, "timed_marathon": 41,
            "run_sudden": 9, "run_sprint": 22, "run_classic": 38, "run_survivor": 61,
        ]
        for (id, score) in best { ChallengeSession.debugSeedBest(score, for: id) }
    }

    private static func seedCategories() {
        let progress: [String: Int] = [
            "animals": 12, "food": 7, "travel": 15, "sports": 4, "music": 9, "nature": 11,
        ]
        let service = CategoryService.shared
        for cat in service.categories {
            guard let n = progress[cat.id] else { continue }
            for i in 0..<min(n, cat.puzzles.count) { service.markCompleted(categoryId: cat.id, puzzleIndex: i) }
        }
    }

    // MARK: - In-game script (OCTORDLE_SCREEN=game)

    /// Hero shot: two openers, then three of the *lower* boards solved, so the two boards
    /// on screen stay colourful (solved boards grey out) while "8 left" reads mid-game.
    static func gameScript(for state: GameState) -> [String] {
        ["SLATE", "CRONY"] + state.boards.dropFirst(4).prefix(3).map { $0.targetWord }
    }
    /// Elapsed seconds shown on the hero shot's clock.
    static let gameElapsed: TimeInterval = 141
}
#else
enum PreviewSeed {
    static var isOn: Bool { false }
    static var screen: String? { nil }
    static var noAds: Bool { false }
    static var tab: Octordle.Tab? { nil }
    static func applyIfRequested() {}
}
#endif
