import Foundation

/// Game difficulty levels
enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case relaxed
    case classic
    case challenge
    case ultimate

    var id: String { rawValue }

    static var allCases: [Difficulty] {
        [.ultimate]
    }

    /// Number of boards to solve
    var boardCount: Int {
        switch self {
        case .relaxed: return 2
        case .classic: return 4
        case .challenge: return 4
        case .ultimate: return 8
        }
    }

    /// Maximum number of guesses allowed
    var maxGuesses: Int {
        switch self {
        case .relaxed: return 9
        case .classic: return 9
        case .challenge: return 7
        case .ultimate: return 13
        }
    }

    /// Display name
    var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .classic: return "Classic"
        case .challenge: return "Challenge"
        case .ultimate: return "Octordle"
        }
    }

    /// Description
    var description: String {
        switch self {
        case .relaxed: return "2 boards, 9 guesses"
        case .classic: return "4 boards, 9 guesses"
        case .challenge: return "4 boards, 7 guesses"
        case .ultimate: return "8 words, 13 guesses"
        }
    }

    /// Icon name
    var iconName: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .classic: return "star.fill"
        case .challenge: return "flame.fill"
        case .ultimate: return "bolt.shield.fill"
        }
    }

    /// Calculate star rating based on guesses used.
    /// Scales with how far above the theoretical minimum (one guess per board) the win was,
    /// so it stays achievable for every board count. Ultimate (8 boards, 13 guesses):
    /// ⭐⭐⭐ ≤10 · ⭐⭐ 11–12 · ⭐ 13.
    func starRating(guessesUsed: Int) -> Int {
        let extra = guessesUsed - boardCount
        let allowance = max(1, maxGuesses - boardCount)
        let ratio = Double(extra) / Double(allowance)
        if ratio <= 0.4 {
            return 3
        } else if ratio <= 0.8 {
            return 2
        } else {
            return 1
        }
    }
}
