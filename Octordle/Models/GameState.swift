import Foundation

/// Game mode
enum GameMode: String, Codable {
    case daily
    case practice
    case unlimited
}

/// Complete game state
struct GameState: Codable, Equatable {
    let mode: GameMode
    let difficulty: Difficulty
    var boards: [BoardData]
    var currentGuess: String
    var guessCount: Int
    var isGameOver: Bool
    var isWon: Bool
    var startTime: Date
    var endTime: Date?
    var dailyDate: String? // Format: "yyyy-MM-dd"
    var accumulatedTime: TimeInterval = 0 // Total seconds from previous sessions

    init(mode: GameMode, difficulty: Difficulty, words: [String]) {
        self.mode = mode
        self.difficulty = difficulty
        self.boards = words.map { BoardData(targetWord: $0, maxGuesses: difficulty.maxGuesses) }
        self.currentGuess = ""
        self.guessCount = 0
        self.isGameOver = false
        self.isWon = false
        self.startTime = Date()
        self.endTime = nil
        self.dailyDate = mode == .daily ? Self.todayString() : nil
        self.accumulatedTime = 0
    }

    // Custom Codable to handle backward compatibility (old saves without accumulatedTime)
    enum CodingKeys: String, CodingKey {
        case mode, difficulty, boards, currentGuess, guessCount
        case isGameOver, isWon, startTime, endTime, dailyDate, accumulatedTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(GameMode.self, forKey: .mode)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        boards = try container.decode([BoardData].self, forKey: .boards)
        currentGuess = try container.decode(String.self, forKey: .currentGuess)
        guessCount = try container.decode(Int.self, forKey: .guessCount)
        isGameOver = try container.decode(Bool.self, forKey: .isGameOver)
        isWon = try container.decode(Bool.self, forKey: .isWon)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        dailyDate = try container.decodeIfPresent(String.self, forKey: .dailyDate)
        accumulatedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedTime) ?? 0
    }

    /// Get combined letter states from all boards for keyboard
    func getCombinedLetterStates() -> [Character: LetterState] {
        var combined: [Character: LetterState] = [:]

        for board in boards {
            for (char, state) in board.letterStates {
                let currentPriority = combined[char]?.priority ?? 0
                if state.priority > currentPriority {
                    combined[char] = state
                }
            }
        }

        return combined
    }

    /// Get per-board letter states for split keyboard rendering
    func getPerBoardLetterStates() -> [Character: KeyColorStates] {
        var result: [Character: [LetterState]] = [:]

        for (boardIndex, board) in boards.enumerated() {
            for (char, state) in board.letterStates {
                if result[char] == nil {
                    result[char] = Array(repeating: .empty, count: boards.count)
                }
                result[char]![boardIndex] = state
            }
        }

        return result.mapValues { KeyColorStates(states: $0) }
    }

    /// Check if all boards are solved
    var allBoardsSolved: Bool {
        boards.allSatisfy { $0.isSolved }
    }

    /// Check if game should end (all solved or out of guesses)
    var shouldEndGame: Bool {
        allBoardsSolved || guessCount >= difficulty.maxGuesses
    }

    /// Remaining guesses
    var remainingGuesses: Int {
        difficulty.maxGuesses - guessCount
    }

    /// Calculate star rating
    var starRating: Int {
        guard isWon else { return 0 }
        return difficulty.starRating(guessesUsed: guessCount)
    }

    /// Elapsed time in seconds (only counts actual play time)
    var elapsedSeconds: Int {
        if endTime != nil {
            // Game is over — return final accumulated time
            return Int(accumulatedTime)
        }
        // Game in progress — accumulated + current session
        return Int(accumulatedTime + Date().timeIntervalSince(startTime))
    }

    /// Format elapsed time as string
    var elapsedTimeString: String {
        let seconds = elapsedSeconds
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    /// Today's date string
    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Reconstruct a GameState from a GameResult (for reviewing completed games)
    init(from result: GameResult) {
        self.mode = result.mode
        self.difficulty = result.difficulty
        self.boards = result.boardResults.map { boardResult in
            var board = BoardData(targetWord: boardResult.targetWord, maxGuesses: result.difficulty.maxGuesses)
            board.isSolved = boardResult.isSolved
            board.solvedAtGuess = boardResult.solvedAtGuess
            return board
        }
        self.currentGuess = ""
        self.guessCount = result.guessCount
        self.isGameOver = true
        self.isWon = result.isWon
        self.startTime = result.date
        self.endTime = result.date
        self.dailyDate = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: result.date)
        }()
        self.accumulatedTime = TimeInterval(result.elapsedSeconds)
    }

    /// Generate share text
    func generateShareText() -> String {
        var text = "Octordle \(mode == .daily ? "Daily" : "Practice") \(difficulty.displayName)\n"
        text += isWon ? "🎉 \(guessCount)/\(difficulty.maxGuesses)" : "❌ X/\(difficulty.maxGuesses)"
        text += " ⏱️ \(elapsedTimeString)\n\n"

        // Board results
        let boardResults = boards.map { board -> String in
            if board.isSolved {
                return "✅ \(board.solvedAtGuess ?? 0)"
            } else {
                return "❌"
            }
        }

        if boards.count == 2 {
            // 2 boards: horizontal layout
            text += "\(boardResults[0]) | \(boardResults[1])\n"
        } else {
            // 4 or 8 boards: 2-column grid
            for row in stride(from: 0, to: boardResults.count, by: 2) {
                let right = row + 1 < boardResults.count ? boardResults[row + 1] : ""
                text += "\(boardResults[row]) | \(right)\n"
                if row + 2 < boardResults.count {
                    text += "——————\n"
                }
            }
        }

        return text
    }

    /// Generate emoji grid for sharing
    func generateEmojiGrid() -> String {
        var text = "Octordle \(mode == .daily ? "Daily" : "Practice")\n\n"

        for (index, board) in boards.enumerated() {
            text += "Board \(index + 1):\n"
            for row in board.guesses {
                for tile in row {
                    switch tile.state {
                    case .correct: text += "🟩"
                    case .present: text += "🟨"
                    case .absent: text += "⬛"
                    default: text += "⬜"
                    }
                }
                text += "\n"
            }
            text += "\n"
        }

        return text
    }
}
