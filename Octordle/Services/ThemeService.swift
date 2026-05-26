import SwiftUI
import UIKit

/// How a theme is unlocked
enum ThemeUnlockType: Equatable {
    case free
    case wins(required: Int)
    case streak(required: Int)
    case premium
}

/// Theme definitions
enum BoardTheme: String, CaseIterable, Identifiable, Codable {
    // Free
    case classic

    // Wins-based unlocks
    case mint       // 2 wins
    case lavender   // 5 wins
    case rose       // 10 wins
    case amber      // 25 wins

    // Streak-based unlocks
    case sky        // 3 day streak
    case berry      // 7 day streak
    case copper     // 10 day streak
    case aurora     // 25 day streak

    // Premium
    case ocean
    case forest
    case sunset

    var id: String { rawValue }

    var unlockType: ThemeUnlockType {
        switch self {
        case .classic: return .free
        case .mint: return .wins(required: 2)
        case .lavender: return .wins(required: 5)
        case .rose: return .wins(required: 10)
        case .amber: return .wins(required: 25)
        case .sky: return .streak(required: 3)
        case .berry: return .streak(required: 7)
        case .copper: return .streak(required: 10)
        case .aurora: return .streak(required: 25)
        case .ocean: return .premium
        case .forest: return .premium
        case .sunset: return .premium
        }
    }

    var isPremium: Bool {
        unlockType == .premium
    }

    /// Check if theme is unlocked for given stats
    func isUnlocked(isPremium: Bool, totalWins: Int, maxStreak: Int) -> Bool {
        switch unlockType {
        case .free: return true
        case .wins(let required): return totalWins >= required
        case .streak(let required): return maxStreak >= required
        case .premium: return isPremium
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .mint: return "Mint"
        case .lavender: return "Lavender"
        case .rose: return "Rose"
        case .amber: return "Amber"
        case .sky: return "Sky"
        case .berry: return "Berry"
        case .copper: return "Copper"
        case .aurora: return "Aurora"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        }
    }

    var unlockDescription: String {
        switch unlockType {
        case .free: return "Default"
        case .wins(let required): return "Win \(required) games"
        case .streak(let required): return "\(required)-day streak"
        case .premium: return "Premium"
        }
    }

    /// Correct letter color (blue tones)
    var correctColor: Color {
        switch self {
        case .classic:  return Color(red: 0.39, green: 0.58, blue: 0.93) // Cornflower blue
        case .mint:     return Color(red: 0.30, green: 0.62, blue: 0.70) // Teal
        case .lavender: return Color(red: 0.50, green: 0.48, blue: 0.88) // Soft indigo
        case .rose:     return Color(red: 0.42, green: 0.56, blue: 0.82) // Dusty blue
        case .amber:    return Color(red: 0.55, green: 0.42, blue: 0.30) // Warm brown
        case .sky:      return Color(red: 0.38, green: 0.65, blue: 0.92) // Sky blue
        case .berry:    return Color(red: 0.45, green: 0.40, blue: 0.78) // Deep purple
        case .copper:   return Color(red: 0.35, green: 0.55, blue: 0.72) // Slate blue
        case .aurora:   return Color(red: 0.25, green: 0.65, blue: 0.68) // Aurora teal
        case .ocean:    return Color(red: 0.25, green: 0.55, blue: 0.85) // Ocean blue
        case .forest:   return Color(red: 0.35, green: 0.60, blue: 0.75) // Forest teal
        case .sunset:   return Color(red: 0.45, green: 0.55, blue: 0.90) // Sunset blue
        }
    }

    /// Present letter color (warm tones — distinct per theme)
    var presentColor: Color {
        switch self {
        case .classic:  return Color(red: 0.85, green: 0.65, blue: 0.25) // Amber gold
        case .mint:     return Color(red: 0.90, green: 0.52, blue: 0.50) // Coral
        case .lavender: return Color(red: 0.88, green: 0.72, blue: 0.35) // Warm yellow
        case .rose:     return Color(red: 0.82, green: 0.48, blue: 0.55) // Dusty rose
        case .amber:    return Color(red: 0.78, green: 0.55, blue: 0.22) // Burnt amber
        case .sky:      return Color(red: 0.92, green: 0.62, blue: 0.45) // Peach
        case .berry:    return Color(red: 0.72, green: 0.78, blue: 0.30) // Lime
        case .copper:   return Color(red: 0.82, green: 0.56, blue: 0.38) // Copper
        case .aurora:   return Color(red: 0.80, green: 0.42, blue: 0.65) // Magenta
        case .ocean:    return Color(red: 0.90, green: 0.55, blue: 0.40) // Sandy coral
        case .forest:   return Color(red: 0.82, green: 0.62, blue: 0.20) // Autumn orange
        case .sunset:   return Color(red: 0.88, green: 0.48, blue: 0.52) // Warm rose
        }
    }

    /// Absent letter color (gray)
    var absentColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.23, green: 0.24, blue: 0.25, alpha: 1)
                : UIColor(red: 0.47, green: 0.49, blue: 0.51, alpha: 1)
        })
    }

    /// Empty tile color
    var emptyColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 1)
                : UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
        })
    }

    /// Empty tile border color
    var emptyBorderColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1)
                : UIColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1)
        })
    }

    /// Typing tile border color
    var typingBorderColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1)
                : UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1)
        })
    }

    /// Current input row border color
    var currentRowBorderColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.38, blue: 0.46, alpha: 1)
                : UIColor(red: 0.68, green: 0.66, blue: 0.62, alpha: 1)
        })
    }

    /// Background color
    var backgroundColor: Color {
        Color(UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            switch self {
            case .classic:
                return isDark
                    ? UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
                    : UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
            case .mint:
                return isDark
                    ? UIColor(red: 0.06, green: 0.10, blue: 0.11, alpha: 1)
                    : UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1)
            case .lavender:
                return isDark
                    ? UIColor(red: 0.08, green: 0.07, blue: 0.13, alpha: 1)
                    : UIColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1)
            case .rose:
                return isDark
                    ? UIColor(red: 0.10, green: 0.08, blue: 0.09, alpha: 1)
                    : UIColor(red: 0.98, green: 0.95, blue: 0.96, alpha: 1)
            case .amber:
                return isDark
                    ? UIColor(red: 0.10, green: 0.09, blue: 0.06, alpha: 1)
                    : UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1)
            case .sky:
                return isDark
                    ? UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1)
                    : UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1)
            case .berry:
                return isDark
                    ? UIColor(red: 0.09, green: 0.07, blue: 0.11, alpha: 1)
                    : UIColor(red: 0.97, green: 0.95, blue: 0.98, alpha: 1)
            case .copper:
                return isDark
                    ? UIColor(red: 0.10, green: 0.08, blue: 0.07, alpha: 1)
                    : UIColor(red: 0.98, green: 0.96, blue: 0.95, alpha: 1)
            case .aurora:
                return isDark
                    ? UIColor(red: 0.06, green: 0.09, blue: 0.10, alpha: 1)
                    : UIColor(red: 0.94, green: 0.97, blue: 0.97, alpha: 1)
            case .ocean:
                return isDark
                    ? UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
                    : UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)
            case .forest:
                return isDark
                    ? UIColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1)
                    : UIColor(red: 0.94, green: 0.96, blue: 0.94, alpha: 1)
            case .sunset:
                return isDark
                    ? UIColor(red: 0.10, green: 0.08, blue: 0.08, alpha: 1)
                    : UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 1)
            }
        })
    }

    /// Keyboard background color
    var keyboardBackgroundColor: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.35, blue: 0.42, alpha: 1)
                : UIColor(red: 0.85, green: 0.83, blue: 0.80, alpha: 1)
        })
    }

    // MARK: - Grouping

    static var freeThemes: [BoardTheme] { [.classic] }
    static var winsThemes: [BoardTheme] { [.mint, .lavender, .rose, .amber] }
    static var streakThemes: [BoardTheme] { [.sky, .berry, .copper, .aurora] }
    static var premiumThemes: [BoardTheme] { [.ocean, .forest, .sunset] }
}

/// Color scheme preference
enum ColorSchemePreference: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Theme service singleton
@MainActor
class ThemeService: ObservableObject {
    static let shared = ThemeService()

    private let defaults = UserDefaults.standard
    private let themeKey = "octordle_boardTheme"
    private let colorSchemeKey = "octordle_colorScheme"
    private let hapticKey = "octordle_hapticEnabled"
    private let soundKey = "octordle_soundEnabled"

    @Published var selectedTheme: BoardTheme {
        didSet {
            defaults.set(selectedTheme.rawValue, forKey: themeKey)
        }
    }

    @Published var colorSchemePreference: ColorSchemePreference {
        didSet {
            defaults.set(colorSchemePreference.rawValue, forKey: colorSchemeKey)
        }
    }

    @Published var hapticEnabled: Bool {
        didSet {
            defaults.set(hapticEnabled, forKey: hapticKey)
            HapticManager.shared.reloadSettings()
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: soundKey)
            HapticManager.shared.reloadSettings()
        }
    }

    var colorScheme: ColorScheme? {
        switch colorSchemePreference {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Get effective theme (fallback to classic if locked)
    func effectiveTheme(isPremium: Bool, totalWins: Int, maxStreak: Int) -> BoardTheme {
        if selectedTheme.isUnlocked(isPremium: isPremium, totalWins: totalWins, maxStreak: maxStreak) {
            return selectedTheme
        }
        return .classic
    }

    /// Legacy convenience (backward compatible)
    func effectiveTheme(isPremium: Bool) -> BoardTheme {
        let stats = StatsService.shared
        return effectiveTheme(isPremium: isPremium, totalWins: stats.totalWins, maxStreak: stats.maxStreak)
    }

    private init() {
        if let themeRaw = defaults.string(forKey: themeKey),
           let theme = BoardTheme(rawValue: themeRaw) {
            self.selectedTheme = theme
        } else {
            self.selectedTheme = .classic
        }

        if let schemeRaw = defaults.string(forKey: colorSchemeKey),
           let scheme = ColorSchemePreference(rawValue: schemeRaw) {
            self.colorSchemePreference = scheme
        } else {
            self.colorSchemePreference = .system
        }

        self.hapticEnabled = defaults.object(forKey: hapticKey) as? Bool ?? true
        self.soundEnabled = defaults.object(forKey: soundKey) as? Bool ?? true
    }
}
