import Foundation

/// A themed word pack for Categories mode. Loaded from Resources/categories.json;
/// every answer word is guaranteed (by the generator script) to be 5 letters and
/// present in the guess dictionary, so all answers are always typeable.
struct WordCategory: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let free: Bool
    /// Fixed puzzles — each is the 8 answer words for one game. Precomputed so
    /// every player gets the same "Animals #3" and results are shareable.
    let puzzles: [[String]]

    var puzzleCount: Int { puzzles.count }
}

/// Top-level structure of categories.json
struct WordCategoryData: Codable {
    let categories: [WordCategory]
}
