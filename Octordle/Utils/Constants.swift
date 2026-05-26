import Foundation

/// App constants
enum Constants {
    /// App information
    enum App {
        static let name = "Octordle"
        static let bundleId = "com.ikuhei.octordle"
        static let appStoreId = "6758416573"
        static let appStoreURL = "https://apps.apple.com/us/app/octordle/id6758416573"
    }

    /// Game settings
    enum Game {
        static let wordLength = 5
        static let boardCount = 8
        static let defaultDifficulty = Difficulty.ultimate
    }

    /// Game Center
    enum GameCenter {
        /// Recurring (daily) leaderboard for the daily Octordle puzzle.
        /// Configure this ID in App Store Connect as a recurring leaderboard,
        /// sort order "Low to High" (lower score = better), integer format.
        static let dailyLeaderboardID = "com.ikuhei.octordle.daily"

        /// Number of boards used when encoding/decoding the composite score.
        static let boardCount = 8

        /// Multiplier separating the "unsolved boards" (high-order) component
        /// from the "guess count" (low-order) component of the score.
        /// Must exceed the max possible guess component (8 boards × 14 = 112).
        static let unsolvedWeight = 1000
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
    }

    /// AdMob IDs
    enum AdMob {
        static let appId = "ca-app-pub-5654617376526903~3494606302"

        // Production Ad Unit IDs
        static let prodBannerAdUnitId = "ca-app-pub-5654617376526903/9122736882"

        // Google's official test Ad Unit IDs (always return test ads)
        static let testBannerAdUnitId = "ca-app-pub-3940256099942544/2934735716"

        #if DEBUG
        static let bannerAdUnitId = testBannerAdUnitId
        #else
        static let bannerAdUnitId = prodBannerAdUnitId
        #endif
    }
}
