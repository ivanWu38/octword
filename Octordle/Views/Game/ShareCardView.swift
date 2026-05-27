import SwiftUI

/// Share card image — an editorial "clipping" from the Daily Edition.
struct ShareCardView: View {
    let gameState: GameState
    let streak: Int
    let puzzleNumber: Int?
    let boardTheme: BoardTheme
    let isDarkMode: Bool

    private let cardWidth: CGFloat = 340

    // MARK: - Data

    private var solvedCount: Int { gameState.boards.filter { $0.isSolved }.count }
    private var totalBoards: Int { gameState.boards.count }

    private var resultSubtitle: String {
        gameState.isWon
            ? "Solved all \(totalBoards) in \(gameState.guessCount) guesses"
            : "Solved \(solvedCount) of \(totalBoards) boards"
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    // MARK: - Palette (resolved by mode, since this renders to an image)

    private func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    private var paper: Color { isDarkMode ? c(0.090, 0.075, 0.055) : c(0.957, 0.941, 0.902) }
    private var ink: Color { isDarkMode ? c(0.929, 0.898, 0.831) : c(0.149, 0.133, 0.110) }
    private var secondary: Color { isDarkMode ? c(0.604, 0.561, 0.486) : c(0.541, 0.510, 0.459) }
    private var line: Color { isDarkMode ? c(0.235, 0.204, 0.165) : c(0.847, 0.816, 0.749) }
    private var terracotta: Color { isDarkMode ? c(0.824, 0.337, 0.173) : c(0.682, 0.255, 0.141) }
    private var amber: Color { isDarkMode ? c(0.925, 0.698, 0.243) : c(0.890, 0.647, 0.184) }
    private var greyTile: Color { isDarkMode ? c(0.329, 0.298, 0.247) : c(0.655, 0.627, 0.553) }

    // MARK: - Body

    var body: some View {
        ZStack {
            Rectangle().fill(paper)

            VStack(spacing: 0) {
                // Masthead
                Text("THE DAILY EDITION")
                    .font(.system(size: 9, weight: .medium)).tracking(2.5)
                    .foregroundColor(secondary)
                    .padding(.bottom, 6)
                Rectangle().fill(ink).frame(height: 1)
                Text("Octordle")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(ink)
                    .padding(.vertical, 6)
                Rectangle().fill(ink).frame(height: 1)
                Text(puzzleNumber.map { "No. \($0)  ·  \(dateString)" } ?? dateString)
                    .font(.system(size: 9, weight: .medium)).tracking(2)
                    .foregroundColor(secondary)
                    .padding(.top, 6)

                // Result
                Text("\(solvedCount) / \(totalBoards)")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundColor(ink)
                    .padding(.top, 16)
                Text(resultSubtitle)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(secondary)
                    .padding(.top, 2)

                if gameState.isWon {
                    HStack(spacing: 5) {
                        ForEach(0..<3) { i in
                            Text("★")
                                .font(.system(size: 16))
                                .foregroundColor(i < gameState.starRating ? amber : line)
                        }
                    }
                    .padding(.top, 8)
                }

                // Boards
                boardsGrid.padding(.top, 16)

                // Footer
                Rectangle().fill(line).frame(height: 1).padding(.top, 16).padding(.bottom, 10)
                HStack {
                    Text("Can you beat this? — Octordle")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(terracotta)
                    Spacer()
                    Text("🔥 \(streak)")
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .foregroundColor(secondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
        }
        .frame(width: cardWidth)
        .clipped()
    }

    // MARK: - Boards Grid

    private var boardsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(gameState.boards.enumerated()), id: \.offset) { index, board in
                boardCell(board: board, index: index + 1)
            }
        }
    }

    private func boardCell(board: BoardData, index: Int) -> some View {
        HStack(spacing: 8) {
            miniTileGrid(for: board)
            VStack(alignment: .leading, spacing: 1) {
                Text("Board \(index)")
                    .font(.system(size: 8, weight: .medium)).tracking(0.5)
                    .foregroundColor(secondary)
                if board.isSolved {
                    Text("\(board.solvedAtGuess ?? 0)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(ink)
                } else {
                    Text("✕")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(terracotta)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .overlay(Rectangle().stroke(line, lineWidth: 1))
    }

    private func miniTileGrid(for board: BoardData) -> some View {
        VStack(spacing: 1.5) {
            ForEach(Array(board.guesses.prefix(13).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1.5) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, tile in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(miniTileColor(for: tile.state))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
    }

    private func miniTileColor(for state: LetterState) -> Color {
        switch state {
        case .correct: return terracotta
        case .present: return amber
        default: return greyTile
        }
    }
}

// MARK: - Image Rendering

extension ShareCardView {
    @MainActor
    static func renderImage(
        gameState: GameState,
        streak: Int,
        puzzleNumber: Int?,
        boardTheme: BoardTheme,
        isDarkMode: Bool
    ) -> UIImage? {
        let view = ShareCardView(
            gameState: gameState,
            streak: streak,
            puzzleNumber: puzzleNumber,
            boardTheme: boardTheme,
            isDarkMode: isDarkMode
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
