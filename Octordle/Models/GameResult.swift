import Foundation

/// Represents a completed game result for statistics
struct GameResult: Codable, Identifiable {
    let id: UUID
    let date: Date
    let mode: GameMode
    let difficulty: Difficulty
    let isWon: Bool
    let guessCount: Int
    let elapsedSeconds: Int
    let starRating: Int
    let boardResults: [BoardResult]

    init(from gameState: GameState) {
        self.id = UUID()
        self.date = Date()
        self.mode = gameState.mode
        self.difficulty = gameState.difficulty
        self.isWon = gameState.isWon
        self.guessCount = gameState.guessCount
        self.elapsedSeconds = gameState.elapsedSeconds
        self.starRating = gameState.starRating
        self.boardResults = gameState.boards.map { BoardResult(from: $0) }
    }

    // Safe decoding: missing or new fields won't break old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.date = (try? container.decode(Date.self, forKey: .date)) ?? Date()
        self.mode = (try? container.decode(GameMode.self, forKey: .mode)) ?? .practice
        self.difficulty = (try? container.decode(Difficulty.self, forKey: .difficulty)) ?? .ultimate
        self.isWon = (try? container.decode(Bool.self, forKey: .isWon)) ?? false
        self.guessCount = (try? container.decode(Int.self, forKey: .guessCount)) ?? 0
        self.elapsedSeconds = (try? container.decode(Int.self, forKey: .elapsedSeconds)) ?? 0
        self.starRating = (try? container.decode(Int.self, forKey: .starRating)) ?? 0
        self.boardResults = (try? container.decode([BoardResult].self, forKey: .boardResults)) ?? []
    }
}

/// Result for a single board
struct BoardResult: Codable {
    let targetWord: String
    let isSolved: Bool
    let solvedAtGuess: Int?

    init(from board: BoardData) {
        self.targetWord = board.targetWord
        self.isSolved = board.isSolved
        self.solvedAtGuess = board.solvedAtGuess
    }

    // Safe decoding: missing or new fields won't break old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetWord = (try? container.decode(String.self, forKey: .targetWord)) ?? ""
        self.isSolved = (try? container.decode(Bool.self, forKey: .isSolved)) ?? false
        self.solvedAtGuess = try? container.decode(Int.self, forKey: .solvedAtGuess)
    }
}
