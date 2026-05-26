import Foundation

/// Represents a single game board (one of eight in Octordle)
struct BoardData: Identifiable, Codable, Equatable {
    let id: UUID
    let targetWord: String
    var guesses: [[TileData]]
    var isSolved: Bool
    var solvedAtGuess: Int?
    let maxGuesses: Int

    init(id: UUID = UUID(), targetWord: String, maxGuesses: Int) {
        self.id = id
        self.targetWord = targetWord.uppercased()
        self.maxGuesses = maxGuesses
        self.guesses = []
        self.isSolved = false
        self.solvedAtGuess = nil
    }

    /// Tracks which letters have been used and their states
    var letterStates: [Character: LetterState] {
        var states: [Character: LetterState] = [:]
        for row in guesses {
            for tile in row {
                guard !tile.letter.isEmpty else { continue }
                let char = Character(tile.letter)
                let currentPriority = states[char]?.priority ?? 0
                if tile.state.priority > currentPriority {
                    states[char] = tile.state
                }
            }
        }
        return states
    }

    /// Evaluate a guess against the target word
    /// Uses the standard Wordle algorithm:
    /// 1. First pass: mark correct positions
    /// 2. Second pass: mark present letters (respecting letter counts)
    mutating func evaluateGuess(_ guess: String) -> [TileData] {
        let guessUpper = guess.uppercased()
        let targetChars = Array(targetWord)
        let guessChars = Array(guessUpper)

        // Count occurrences of each letter in target
        var letterCounts: [Character: Int] = [:]
        for char in targetChars {
            letterCounts[char, default: 0] += 1
        }

        var tiles: [TileData] = []
        var states: [LetterState] = Array(repeating: .absent, count: 5)

        // First pass: mark correct positions
        for i in 0..<5 {
            if guessChars[i] == targetChars[i] {
                states[i] = .correct
                letterCounts[guessChars[i], default: 0] -= 1
            }
        }

        // Second pass: mark present letters
        for i in 0..<5 {
            if states[i] != .correct {
                let char = guessChars[i]
                if letterCounts[char, default: 0] > 0 {
                    states[i] = .present
                    letterCounts[char, default: 0] -= 1
                }
            }
        }

        // Create tiles
        for i in 0..<5 {
            tiles.append(TileData(letter: String(guessChars[i]), state: states[i]))
        }

        // Add to guesses
        guesses.append(tiles)

        // Check if solved
        if guessUpper == targetWord {
            isSolved = true
            solvedAtGuess = guesses.count
        }

        return tiles
    }

    /// Get display tiles for a specific row
    func tilesForRow(_ row: Int, currentInput: String = "") -> [TileData] {
        if row < guesses.count {
            return guesses[row]
        }

        // For the current input row
        if row == guesses.count && !currentInput.isEmpty {
            var tiles: [TileData] = []
            let inputChars = Array(currentInput.uppercased())
            for i in 0..<5 {
                if i < inputChars.count {
                    tiles.append(TileData(letter: String(inputChars[i]), state: .typing))
                } else {
                    tiles.append(TileData.empty())
                }
            }
            return tiles
        }

        // Empty row
        return (0..<5).map { _ in TileData.empty() }
    }
}
