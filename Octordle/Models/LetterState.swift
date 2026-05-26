import SwiftUI

/// Represents the state of a letter in the game
enum LetterState: String, Codable, Equatable {
    case empty      // No letter entered
    case typing     // Currently being typed (current row)
    case correct    // Letter is in correct position (green)
    case present    // Letter exists but wrong position (yellow)
    case absent     // Letter doesn't exist in word (gray)

    /// Priority for keyboard state merging (higher wins)
    var priority: Int {
        switch self {
        case .empty: return 0
        case .typing: return 1
        case .absent: return 2
        case .present: return 3
        case .correct: return 4
        }
    }
}

/// Per-board letter states for split keyboard rendering
struct KeyColorStates: Equatable {
    let states: [LetterState]

    /// True when all boards share the same state (skip split rendering)
    var isUniform: Bool {
        guard let first = states.first else { return true }
        return states.allSatisfy { $0 == first }
    }

    /// Highest-priority state across all boards (used for text color)
    var bestState: LetterState {
        states.max(by: { $0.priority < $1.priority }) ?? .empty
    }

    /// Color for a specific board index
    func color(for boardIndex: Int, theme: BoardTheme) -> Color {
        guard boardIndex < states.count else { return theme.keyboardBackgroundColor }
        switch states[boardIndex] {
        case .empty, .typing:
            return theme.keyboardBackgroundColor
        case .correct:
            return theme.correctColor
        case .present:
            return theme.presentColor
        case .absent:
            return theme.absentColor
        }
    }

    /// Default empty state for all boards
    static func empty(boardCount: Int) -> KeyColorStates {
        KeyColorStates(states: Array(repeating: .empty, count: boardCount))
    }
}
