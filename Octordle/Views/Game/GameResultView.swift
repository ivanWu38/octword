import SwiftUI

/// Game result view shown after game ends
struct GameResultView: View {
    let gameState: GameState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @State private var answersHidden = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Result header
                        resultHeader

                        // Star rating (if won)
                        if gameState.isWon {
                            starRating
                        }

                        // Board results
                        boardResultsGrid

                        // Statistics
                        statisticsSection
                    }
                    .padding()
                }

                // Action buttons pinned to bottom
                actionButtons
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .padding(.top, 12)
            }
            .background(Color.quordleBackground.ignoresSafeArea())
            .navigationTitle(gameState.isWon ? "Victory!" : "Game Over")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.quordleSecondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: gameState.isWon ? "trophy.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(gameState.isWon ? .quordleGold : .red)

            Text(gameState.isWon ? "Congratulations!" : "Better luck next time!")
                .font(.title2.bold())
                .foregroundColor(.quordlePrimaryText)

            HStack(spacing: 20) {
                Label("\(gameState.guessCount)/\(gameState.difficulty.maxGuesses)", systemImage: "number")
                Label(gameState.elapsedTimeString, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundColor(.quordleSecondaryText)
        }
    }

    // MARK: - Star Rating

    private var starRating: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Image(systemName: index < gameState.starRating ? "star.fill" : "star")
                    .font(.title)
                    .foregroundColor(index < gameState.starRating ? .quordleGold : .quordleSecondaryText)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Board Results Grid

    private var boardResultsGrid: some View {
        VStack(spacing: 8) {
            // Hide/Show answers toggle (Daily mode only)
            if gameState.mode == .daily {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.buttonTap()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            answersHidden.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: answersHidden ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                            Text(answersHidden ? "Show Answers" : "Hide Answers")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.quordleSecondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.quordleSecondaryText.opacity(0.1))
                        )
                    }
                }
            }

            // Dynamic rows: 2 boards per row
            let rowCount = gameState.boards.count / 2
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 8) {
                    boardResultCard(board: gameState.boards[row * 2], index: row * 2 + 1)
                    boardResultCard(board: gameState.boards[row * 2 + 1], index: row * 2 + 2)
                }
            }
        }
    }

    private func boardResultCard(board: BoardData, index: Int) -> some View {
        VStack(spacing: 4) {
            Text("Board \(index)")
                .font(.caption)
                .foregroundColor(.quordleSecondaryText)

            if answersHidden && gameState.mode == .daily {
                Text(String(repeating: "●", count: board.targetWord.count))
                    .font(.headline.bold())
                    .foregroundColor(.quordleSecondaryText.opacity(0.3))
            } else {
                Text(board.targetWord)
                    .font(.headline.bold())
                    .foregroundColor(.quordlePrimaryText)
            }

            if board.isSolved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.quordleCorrect)
                    Text("Guess \(board.solvedAtGuess ?? 0)")
                }
                .font(.caption)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not solved")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.quordlePrimaryText)

            HStack(spacing: 16) {
                StatItem(value: "\(gameState.boards.filter { $0.isSolved }.count)/\(gameState.boards.count)", label: "Boards Solved")
                StatItem(value: gameState.difficulty.displayName, label: "Difficulty")
                StatItem(value: gameState.mode == .daily ? "Daily" : "Practice", label: "Mode")
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.buttonTap()
                HapticManager.shared.playSound(.click)
                AnalyticsService.logShareResult(gameState: gameState)
                generateAndShare()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Result")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                HapticManager.shared.buttonTap()
                HapticManager.shared.playSound(.click)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    dismiss()
                }
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Share Card Generation

    private func generateAndShare() {
        let isDark = colorScheme == .dark
        let puzzleNumber = gameState.mode == .daily
            ? DailyPuzzleService.shared.puzzleNumber
            : nil

        guard let image = ShareCardView.renderImage(
            gameState: gameState,
            streak: statsService.currentStreak,
            puzzleNumber: puzzleNumber,
            boardTheme: themeService.selectedTheme,
            isDarkMode: isDark
        ) else { return }

        let items: [Any] = [image, Constants.App.appStoreURL]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Walk up to the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        activityVC.popoverPresentationController?.sourceView = topVC.view
        topVC.present(activityVC, animated: true)
    }
}

/// Statistic display item
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.quordlePrimaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(.quordleSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let state = GameState(mode: .daily, difficulty: .classic, words: ["APPLE", "BEACH", "CORAL", "DANCE"])
    return GameResultView(gameState: state)
}
