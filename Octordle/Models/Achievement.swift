import Foundation

/// Achievement definitions — tuned for Octordle (8 boards, 13 guesses).
/// Most are reachable without ever solving all 8: they reward words solved,
/// coming back daily, and standout rounds. A couple stay aspirational.
/// Enum order = display order in the Journey "Marks of Distinction" list.
enum Achievement: String, CaseIterable, Codable, Identifiable {
    // Getting started
    case firstWord          // Solve your first board
    case fullHouse          // Solve all 8 boards in one game

    // Words solved (cumulative — counts boards even in losses)
    case wordCollector      // 25 words
    case wordWizard         // 150 words
    case lexiconMaster      // 600 words

    // Daily streak (consecutive days played)
    case streak3
    case streak7
    case streak30

    // Daily dedication (total editions completed)
    case explorer           // 10 editions
    case dailyDevotee       // 30 editions

    // Standout play
    case sharpEye           // Solve 6+ boards in a single game
    case downToTheWire      // Win on the final guess
    case flawless           // 3-star win (aspirational)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWord: return "First Word"
        case .fullHouse: return "Full House"
        case .wordCollector: return "Word Collector"
        case .wordWizard: return "Word Wizard"
        case .lexiconMaster: return "Lexicon Master"
        case .streak3: return "On a Roll"
        case .streak7: return "Weekly Warrior"
        case .streak30: return "Monthly Master"
        case .explorer: return "Explorer"
        case .dailyDevotee: return "Daily Devotee"
        case .sharpEye: return "Sharp Eye"
        case .downToTheWire: return "Down to the Wire"
        case .flawless: return "Flawless"
        }
    }

    var description: String {
        switch self {
        case .firstWord: return "Solve your first board"
        case .fullHouse: return "Solve all 8 boards in one game"
        case .wordCollector: return "Solve 25 words in total"
        case .wordWizard: return "Solve 150 words in total"
        case .lexiconMaster: return "Solve 600 words in total"
        case .streak3: return "Play 3 days in a row"
        case .streak7: return "Play 7 days in a row"
        case .streak30: return "Play 30 days in a row"
        case .explorer: return "Complete 10 daily editions"
        case .dailyDevotee: return "Complete 30 daily editions"
        case .sharpEye: return "Solve 6 or more boards in one game"
        case .downToTheWire: return "Win on your very last guess"
        case .flawless: return "Win an Octordle with 3 stars"
        }
    }

    var iconName: String {
        switch self {
        case .firstWord: return "checkmark.seal.fill"
        case .fullHouse: return "trophy.fill"
        case .wordCollector: return "square.grid.2x2.fill"
        case .wordWizard: return "wand.and.stars"
        case .lexiconMaster: return "books.vertical.fill"
        case .streak3: return "flame.fill"
        case .streak7: return "bolt.fill"
        case .streak30: return "crown.fill"
        case .explorer: return "map.fill"
        case .dailyDevotee: return "calendar.badge.checkmark"
        case .sharpEye: return "eye.fill"
        case .downToTheWire: return "exclamationmark.triangle.fill"
        case .flawless: return "star.fill"
        }
    }

    /// Progress requirement for this achievement.
    var requirement: Int {
        switch self {
        case .firstWord: return 1
        case .fullHouse: return 1
        case .wordCollector: return 25
        case .wordWizard: return 150
        case .lexiconMaster: return 600
        case .streak3: return 3
        case .streak7: return 7
        case .streak30: return 30
        case .explorer: return 10
        case .dailyDevotee: return 30
        case .sharpEye: return 6
        case .downToTheWire: return 1
        case .flawless: return 1
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

    // Safe decoding: missing or new fields won't break old data, and
    // unknown achievement raw values (e.g. removed ones) are skipped rather
    // than wiping the whole unlocked set.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raws = try? container.decode([String].self, forKey: .unlockedAchievements) {
            self.unlockedAchievements = Set(raws.compactMap { Achievement(rawValue: $0) })
        } else {
            self.unlockedAchievements = (try? container.decode(Set<Achievement>.self, forKey: .unlockedAchievements)) ?? []
        }
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
