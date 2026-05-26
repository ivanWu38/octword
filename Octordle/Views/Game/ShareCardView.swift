import SwiftUI

/// Share card image generator for game results
struct ShareCardView: View {
    let gameState: GameState
    let streak: Int
    let puzzleNumber: Int?
    let boardTheme: BoardTheme
    let isDarkMode: Bool

    private let cardWidth: CGFloat = 340

    // MARK: - Computed Properties

    private var solvedCount: Int {
        gameState.boards.filter { $0.isSolved }.count
    }

    private var totalBoards: Int {
        gameState.boards.count
    }

    private var modeLabel: String {
        let mode = gameState.mode == .daily ? "Daily" : "Unlimited"
        return "\(mode) \(gameState.difficulty.displayName)"
    }

    private var resultSubtitle: String {
        if gameState.isWon {
            return "Solved all boards in \(gameState.guessCount) guesses"
        } else {
            return "Solved \(solvedCount) boards in \(gameState.guessCount) guesses"
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Colors

    private var cardBackground: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.23),
                    Color(red: 0.09, green: 0.09, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.95, blue: 0.98),
                    Color(red: 0.92, green: 0.91, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var primaryTextColor: Color {
        isDarkMode ? .white : Color(red: 0.15, green: 0.15, blue: 0.18)
    }

    private var secondaryTextColor: Color {
        isDarkMode ? Color(white: 0.53) : Color(white: 0.45)
    }

    private var tertiaryTextColor: Color {
        isDarkMode ? Color(white: 0.4) : Color(white: 0.55)
    }

    private var boardCellBackground: Color {
        isDarkMode
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.04)
    }

    private var dividerColor: Color {
        isDarkMode
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.08)
    }

    private var accentPurple: Color {
        Color(red: 0.61, green: 0.42, blue: 0.94)
    }

    private var winColor: Color {
        Color(red: 0.28, green: 0.75, blue: 0.57)
    }

    private var loseColor: Color {
        Color(red: 0.91, green: 0.36, blue: 0.46)
    }

    // MARK: - Theme-aware tile colors

    private var correctTileColor: Color {
        boardTheme.correctColor
    }

    private var presentTileColor: Color {
        boardTheme.presentColor
    }

    private var absentTileColor: Color {
        isDarkMode
            ? Color(red: 0.23, green: 0.23, blue: 0.32)
            : Color(red: 0.75, green: 0.75, blue: 0.78)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background — no cornerRadius, straight edges for image export
            Rectangle()
                .fill(cardBackground)

            // Decorative gradient orbs — clipped inside card bounds
            decorativeOrbs

            // Content
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 18)

                resultSection
                    .padding(.bottom, 10)

                starsSection
                    .padding(.bottom, 16)

                boardsGrid
                    .padding(.bottom, 16)

                statsRow
                    .padding(.bottom, 16)

                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .frame(width: cardWidth)
        .clipped()
    }

    // MARK: - Decorative Orbs

    private var decorativeOrbs: some View {
        GeometryReader { geo in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gameState.isWon
                                ? winColor.opacity(0.12)
                                : accentPurple.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .position(x: geo.size.width - 30, y: 30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            winColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .position(x: 30, y: geo.size.height - 50)
        }
        .clipped()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 10) {
                // App icon
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Octordle")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(primaryTextColor)

                    Text(modeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }

            Spacer()

            // Puzzle number (only for Daily mode)
            if gameState.mode == .daily, let number = puzzleNumber {
                Text("#\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tertiaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isDarkMode
                                    ? Color.white.opacity(0.15)
                                    : Color.black.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            }
        }
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(spacing: 2) {
            Text("\(solvedCount) / \(totalBoards)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(gameState.isWon ? winColor : loseColor)

            Text(resultSubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryTextColor)
        }
    }

    // MARK: - Stars

    private var starsSection: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Text("★")
                    .font(.system(size: 20))
                    .foregroundColor(
                        index < gameState.starRating
                            ? Color(red: 1.0, green: 0.8, blue: 0.3)
                            : (isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.12))
                    )
                    .shadow(
                        color: index < gameState.starRating
                            ? Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.4)
                            : .clear,
                        radius: 4
                    )
            }
        }
    }

    // MARK: - Boards Grid

    private var boardsGrid: some View {
        let gridSpacing: CGFloat = gameState.boards.count > 4 ? 6 : 8
        let columns = [GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing)]

        return LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(Array(gameState.boards.enumerated()), id: \.offset) { _, board in
                boardCell(board: board)
            }
        }
    }

    private func boardCell(board: BoardData) -> some View {
        VStack(spacing: 3) {
            // Status label
            Text(board.isSolved ? "SOLVED" : "FAILED")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(board.isSolved ? winColor : loseColor)
                .tracking(0.5)

            // Guess number or X mark
            if board.isSolved {
                Text("\(board.solvedAtGuess ?? 0)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(primaryTextColor)
            } else {
                Text("✕")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(loseColor)
            }

            // Guess label
            if board.isSolved {
                Text("guesses")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(tertiaryTextColor)
            } else {
                Text("\(board.guesses.count) / \(board.maxGuesses)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(tertiaryTextColor)
            }

            // Mini tile grid
            miniTileGrid(for: board)
                .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(boardCellBackground)
        )
    }

    // MARK: - Mini Tile Grid

    private func miniTileGrid(for board: BoardData) -> some View {
        VStack(spacing: 1.5) {
            ForEach(Array(board.guesses.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1.5) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, tile in
                        miniTile(state: tile.state)
                    }
                }
            }
        }
    }

    private func miniTile(state: LetterState) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(miniTileColor(for: state))
            .frame(width: 6, height: 6)
    }

    private func miniTileColor(for state: LetterState) -> Color {
        switch state {
        case .correct: return correctTileColor
        case .present: return presentTileColor
        case .absent: return absentTileColor
        default: return absentTileColor
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: gameState.elapsedTimeString, label: "Time")
            statItem(value: "\(solvedCount) / \(totalBoards)", label: "Boards")
            statItem(
                value: gameState.isWon ? "🔥 \(streak)" : "💔 \(streak)",
                label: "Streak"
            )
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(primaryTextColor)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(tertiaryTextColor)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.bottom, 12)

            HStack {
                Text("Can you beat this? → Octordle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentPurple)

                Spacer()

                Text(dateString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tertiaryTextColor)
            }
        }
    }
}

// MARK: - Image Rendering

extension ShareCardView {
    /// Render the share card to a UIImage
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
