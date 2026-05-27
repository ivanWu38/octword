import Foundation

/// Achievement definitions
enum Achievement: String, CaseIterable, Codable, Identifiable {
    // Getting Started
    case firstWin           // Win first game
    case wordWizard         // Solve 100 words
    case centuryClub        // Play 100 games

    // Streak achievements
    case streak3            // 3 wins in a row
    case streak7            // 7 wins in a row
    case streak30           // 30 wins in a row

    // Skill achievements
    case perfectGame        // 3 stars on Octordle
    case speedDemon         // Win under 2 minutes
    case clutchPlayer       // Win with only 1 guess remaining

    // Mode achievements
    case challengeMaster    // 10 Octordle wins
    case dailyDedicated     // 30 daily puzzles
    case explorer           // Complete 10 daily puzzles

    // Special achievements
    case sharpMind          // 5 perfect games
    case quickDraw          // Win under 1 minute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWin: return "First Victory"
        case .wordWizard: return "Word Wizard"
        case .centuryClub: return "Century Club"
        case .streak3: return "On a Roll"
        case .streak7: return "Weekly Warrior"
        case .streak30: return "Monthly Master"
        case .perfectGame: return "Perfect Game"
        case .speedDemon: return "Speed Demon"
        case .clutchPlayer: return "Clutch Player"
        case .challengeMaster: return "Octordle Master"
        case .dailyDedicated: return "Daily Dedicated"
        case .explorer: return "Explorer"
        case .sharpMind: return "Sharp Mind"
        case .quickDraw: return "Quick Draw"
        }
    }

    var description: String {
        switch self {
        case .firstWin: return "Win your first game"
        case .wordWizard: return "Solve 100 words total"
        case .centuryClub: return "Play 100 games"
        case .streak3: return "Win 3 games in a row"
        case .streak7: return "Win 7 games in a row"
        case .streak30: return "Win 30 games in a row"
        case .perfectGame: return "Win with 3 stars in Octordle"
        case .speedDemon: return "Win a game in under 6 minutes"
        case .clutchPlayer: return "Win with only 1 guess remaining"
        case .challengeMaster: return "Win 10 Octordle games"
        case .dailyDedicated: return "Complete 30 daily puzzles"
        case .explorer: return "Complete 10 daily puzzles"
        case .sharpMind: return "Achieve 5 perfect games"
        case .quickDraw: return "Win a game in under 4 minutes"
        }
    }

    var iconName: String {
        switch self {
        case .firstWin: return "trophy.fill"
        case .wordWizard: return "wand.and.stars"
        case .centuryClub: return "medal.fill"
        case .streak3: return "flame.fill"
        case .streak7: return "bolt.fill"
        case .streak30: return "crown.fill"
        case .perfectGame: return "star.fill"
        case .speedDemon: return "hare.fill"
        case .clutchPlayer: return "exclamationmark.triangle.fill"
        case .challengeMaster: return "mountain.2.fill"
        case .dailyDedicated: return "calendar.badge.checkmark"
        case .explorer: return "map.fill"
        case .sharpMind: return "brain.fill"
        case .quickDraw: return "timer"
        }
    }

    var iconColor: String {
        switch self {
        case .firstWin: return "gold"
        case .wordWizard: return "purple"
        case .centuryClub: return "blue"
        case .streak3: return "orange"
        case .streak7: return "orange"
        case .streak30: return "gold"
        case .perfectGame: return "gold"
        case .speedDemon: return "green"
        case .clutchPlayer: return "red"
        case .challengeMaster: return "purple"
        case .dailyDedicated: return "blue"
        case .explorer: return "green"
        case .sharpMind: return "pink"
        case .quickDraw: return "cyan"
        }
    }

    /// Progress requirement for this achievement
    var requirement: Int {
        switch self {
        case .firstWin: return 1
        case .wordWizard: return 100
        case .centuryClub: return 100
        case .streak3: return 3
        case .streak7: return 7
        case .streak30: return 30
        case .perfectGame: return 1
        case .speedDemon: return 1
        case .clutchPlayer: return 1
        case .challengeMaster: return 10
        case .dailyDedicated: return 30
        case .explorer: return 10
        case .sharpMind: return 5
        case .quickDraw: return 1
        }
    }
}

/// Tracks achievement progress
struct AchievementProgress: Codable {
    var unlockedAchievements: Set<Achievement>
    var currentStreak: Int
    var maxStreak: Int
    var challengeWins: Int
    var dailyPuzzlesCompleted: Int
    var perfectGamesCount: Int
    var clutchWinsCount: Int
    var relaxedWins: Int
    var classicWins: Int
    var challengeWinsTotal: Int
    var ultimateWins: Int

    init() {
        self.unlockedAchievements = []
        self.currentStreak = 0
        self.maxStreak = 0
        self.challengeWins = 0
        self.dailyPuzzlesCompleted = 0
        self.perfectGamesCount = 0
        self.clutchWinsCount = 0
        self.relaxedWins = 0
        self.classicWins = 0
        self.challengeWinsTotal = 0
        self.ultimateWins = 0
    }

    // Safe decoding: missing or new fields won't break old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.unlockedAchievements = (try? container.decode(Set<Achievement>.self, forKey: .unlockedAchievements)) ?? []
        self.currentStreak = (try? container.decode(Int.self, forKey: .currentStreak)) ?? 0
        self.maxStreak = (try? container.decode(Int.self, forKey: .maxStreak)) ?? 0
        self.challengeWins = (try? container.decode(Int.self, forKey: .challengeWins)) ?? 0
        self.dailyPuzzlesCompleted = (try? container.decode(Int.self, forKey: .dailyPuzzlesCompleted)) ?? 0
        self.perfectGamesCount = (try? container.decode(Int.self, forKey: .perfectGamesCount)) ?? 0
        self.clutchWinsCount = (try? container.decode(Int.self, forKey: .clutchWinsCount)) ?? 0
        self.relaxedWins = (try? container.decode(Int.self, forKey: .relaxedWins)) ?? 0
        self.classicWins = (try? container.decode(Int.self, forKey: .classicWins)) ?? 0
        self.challengeWinsTotal = (try? container.decode(Int.self, forKey: .challengeWinsTotal)) ?? 0
        self.ultimateWins = (try? container.decode(Int.self, forKey: .ultimateWins)) ?? 0
    }
}
