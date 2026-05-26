import Foundation

/// Represents a single tile in the game board
struct TileData: Identifiable, Equatable, Codable {
    let id: UUID
    var letter: String
    var state: LetterState

    init(id: UUID = UUID(), letter: String = "", state: LetterState = .empty) {
        self.id = id
        self.letter = letter
        self.state = state
    }

    static func empty() -> TileData {
        TileData()
    }
}
