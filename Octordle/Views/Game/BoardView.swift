import SwiftUI

/// Single game board view
struct BoardView: View {
    let board: BoardData
    let currentInput: String
    let boardIndex: Int
    let tileSize: CGFloat

    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService

    var body: some View {
        ZStack {
            // Grid of tiles
            VStack(spacing: Constants.Layout.tileSpacing) {
                ForEach(0..<board.maxGuesses, id: \.self) { row in
                    let isCurrentRow = !board.isSolved && row == board.guesses.count
                    HStack(spacing: Constants.Layout.tileSpacing) {
                        ForEach(0..<5, id: \.self) { col in
                            let tiles = board.tilesForRow(row, currentInput: board.isSolved ? "" : currentInput)
                            TileView(
                                tile: tiles[col],
                                size: tileSize,
                                columnIndex: col,
                                shouldAnimate: row == board.guesses.count - 1,
                                isCurrentRow: isCurrentRow,
                                shouldPulse: isCurrentRow && currentInput.isEmpty && col == 0
                            )
                        }
                    }
                }
            }

            // Solved overlay
            if board.isSolved {
                solvedOverlay
            }
        }
    }

    private var solvedOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.5))
            .overlay(
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: tileSize * 1.0))
                        .foregroundColor(.quordleCorrect)

                    Text(board.targetWord)
                        .font(.system(size: tileSize * 0.55, weight: .bold))
                        .foregroundColor(.white)

                    if let solvedAt = board.solvedAtGuess {
                        Text("Guess \(solvedAt)")
                            .font(.system(size: tileSize * 0.35))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            )
    }
}

#Preview {
    let board = BoardData(targetWord: "APPLE", maxGuesses: 9)
    return BoardView(board: board, currentInput: "TES", boardIndex: 0, tileSize: 30)
        .padding()
        .background(Color.quordleBackground)
        .environmentObject(ThemeService.shared)
        .environmentObject(SubscriptionService.shared)
}
