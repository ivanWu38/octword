import Foundation

/// App constants
enum Constants {
    /// App information
    enum App {
        static let name = "Octors"
        static let bundleId = "com.ikuhei.octordle"
        static let appStoreId = "6773183406"
        static let appStoreURL = "https://apps.apple.com/app/id6773183406"
    }

    /// Game settings
    enum Game {
        static let wordLength = 5
        static let boardCount = 8
        static let defaultDifficulty = Difficulty.ultimate
    }

    /// Archive (past daily puzzles)
    enum Archive {
        /// Puzzle #1 — the app's launch day. Earliest playable archive date.
        static let firstPuzzleComponents = DateComponents(year: 2026, month: 5, day: 20)
        /// Today + previous (freeDays - 1) days are free to play; older days need unlocking.
        static let freeDays = 3
    }

    /// Animation durations
    enum Animation {
        static let tileFlipDuration = 0.3
        static let tileFlipDelay = 0.1
        static let keyPressDuration = 0.1
        static let sheetPresentationDelay = 0.5
        static let confettiDuration = 2.5
        static let cursorPulseDuration = 1.0
    }

    /// Spring animation parameters
    enum Spring {
        static let response: Double = 0.3
        static let dampingFraction: Double = 0.6
        static let quickResponse: Double = 0.15
        static let quickDamping: Double = 0.5
    }

    /// Layout
    enum Layout {
        static let boardSpacing: CGFloat = 4
        static let tileSpacing: CGFloat = 2
        static let keyboardSpacing: CGFloat = 4
        static let keyHeight: CGFloat = 58
        static let cornerRadius: CGFloat = 4
        static let currentRowBorderWidth: CGFloat = 1.5
    }

    /// UserDefaults keys
    enum UserDefaultsKeys {
        static let boardTheme = "octordle_boardTheme"
        static let colorScheme = "octordle_colorScheme"
        static let hapticEnabled = "octordle_hapticEnabled"
        static let soundEnabled = "octordle_soundEnabled"
        static let hasSeenOnboarding = "octordle_hasSeenOnboarding"
        static let gameResults = "octordle_gameResults"
        static let achievements = "octordle_achievements"
        static let dailyState = "octordle_dailyState"
        static let completedDailyDates = "octordle_completedDailyDates"
        static let hasSeenNotepadIntro = "octordle_hasSeenNotepadIntro"
        static let archiveUnlockedDates = "octordle_archiveUnlockedDates"
        /// Days whose daily puzzle was completed ON that day (the only days that count toward streak).
        static let streakDates = "octordle_streakDates"
        /// Days restored via the streak-rescue rewarded ad.
        static let rescuedStreakDates = "octordle_rescuedStreakDates"
        static let lastStreakRescueDay = "octordle_lastStreakRescueDay"
        static let streakRescueCardDismissedDay = "octordle_streakRescueCardDismissedDay"
        static let streakDatesMigrated = "octordle_streakDatesMigrated"
    }

    /// Streak rescue (rewarded ad restores a streak that broke by exactly one missed day)
    enum StreakRescue {
        /// Only offer when the broken streak was at least this long.
        static let minStreak = 3
        /// One rescue per rolling window of this many days.
        static let cooldownDays = 7
    }

    /// AdMob IDs
    enum AdMob {
        static let appId = "ca-app-pub-5654617376526903~1673065543"

        // Production Ad Unit IDs
        static let prodBannerAdUnitId = "ca-app-pub-5654617376526903/4751930117"
        static let prodRewardedAdUnitId = "ca-app-pub-5654617376526903/7584303513"
        /// Separate rewarded unit for the "buy me a coffee" support flow (kept
        /// distinct so its performance can be tracked independently).
        static let prodSupportRewardedAdUnitId = "ca-app-pub-5654617376526903/5535012213"
        /// Separate rewarded unit for unlocking themed-category levels.
        static let prodCategoryRewardedAdUnitId = "ca-app-pub-5654617376526903/3122234771"
        /// Separate rewarded unit for restoring a broken daily streak.
        static let prodStreakRescueRewardedAdUnitId = "ca-app-pub-5654617376526903/7542800241"

        // Google's official test Ad Unit IDs (always return test ads)
        static let testBannerAdUnitId = "ca-app-pub-3940256099942544/2934735716"
        static let testRewardedAdUnitId = "ca-app-pub-3940256099942544/1712485313"

        /// DEBUG uses Google test IDs; launch with OCTORDLE_PROD_ADS=1 to hit the real units (mediation diagnostics).
        private static var useProdInDebug: Bool {
            #if DEBUG
            return ProcessInfo.processInfo.environment["OCTORDLE_PROD_ADS"] == "1"
            #else
            return true
            #endif
        }
        static var bannerAdUnitId: String { useProdInDebug ? prodBannerAdUnitId : testBannerAdUnitId }
        static var rewardedAdUnitId: String { useProdInDebug ? prodRewardedAdUnitId : testRewardedAdUnitId }
        static var supportRewardedAdUnitId: String { useProdInDebug ? prodSupportRewardedAdUnitId : testRewardedAdUnitId }
        static var categoryRewardedAdUnitId: String { useProdInDebug ? prodCategoryRewardedAdUnitId : testRewardedAdUnitId }
        static var streakRescueRewardedAdUnitId: String { useProdInDebug ? prodStreakRescueRewardedAdUnitId : testRewardedAdUnitId }

    }
}
