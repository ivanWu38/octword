import SwiftUI

/// Game result view shown after game ends
struct GameResultView: View {
    let gameState: GameState
    /// Provides the cached Solve Report (daily/archive). Optional so previews and any
    /// non-report callers still work.
    var viewModel: GameViewModel? = nil
    var puzzleNumber: Int? = nil
    /// Called when the player taps "View Board" — keep the game on screen so they
    /// can review the board, instead of leaving the game.
    var onReviewBoard: (() -> Void)? = nil
    /// Called when the player taps "Done" / the close button — leave the game.
    /// Falls back to the environment dismiss when not provided.
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @State private var answersHidden = false
    @State private var showSolveReport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        // Result header
                        resultHeader

                        // Star rating (if won)
                        if gameState.isWon {
                            starRating
                        }

                        // The answers
                        answersSection
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.backTap()
                        (onDone ?? { dismiss() })()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.quordleSecondaryText)
                    }
                }
            }
        }
        .sheet(isPresented: $showSolveReport) {
            if let viewModel {
                NavigationStack {
                    SolveReportView(viewModel: viewModel, puzzleNumber: puzzleNumber)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    HapticManager.shared.backTap()
                                    showSolveReport = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.quordleSecondaryText)
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        let solved = gameState.boards.filter { $0.isSolved }.count
        let total = gameState.boards.count
        return VStack(spacing: 10) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
            Text(gameState.isWon ? "Victory" : "Edition Closed")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .padding(.vertical, 2)
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)

            if gameState.isWon {
                Text("SOLVED")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .tracking(3)
                    .foregroundColor(.quordlePrimary)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.quordlePrimary, lineWidth: 2))
                    .rotationEffect(.degrees(-7))
                    .padding(.top, 6)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(solved)").font(.system(size: 44, weight: .bold, design: .serif))
                Text("/ \(total)").font(.system(size: 20, design: .serif)).foregroundColor(.quordleSecondaryText)
            }
            .foregroundColor(.quordlePrimaryText)
            .padding(.top, 4)

            Text("\(gameState.guessCount) guesses  ·  \(gameState.elapsedTimeString)")
                .font(.system(size: 14, design: .serif))
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

    // MARK: - The Answers (editorial ledger)

    private var answersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("The Answers")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                Spacer()
                if gameState.mode == .daily {
                    Button {
                        HapticManager.shared.buttonTap()
                        withAnimation(.easeInOut(duration: 0.2)) { answersHidden.toggle() }
                    } label: {
                        Text(answersHidden ? "Show" : "Hide")
                            .font(.system(size: 12, weight: .semibold, design: .serif))
                            .foregroundColor(.quordlePrimary)
                    }
                }
            }
            .padding(.bottom, 6)

            let rowCount = (gameState.boards.count + 1) / 2
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 18) {
                    answerCell(board: gameState.boards[row * 2], index: row * 2 + 1)
                    if row * 2 + 1 < gameState.boards.count {
                        answerCell(board: gameState.boards[row * 2 + 1], index: row * 2 + 2)
                    } else {
                        Spacer()
                    }
                }
                Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
            }
        }
    }

    private func answerCell(board: BoardData, index: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 14, alignment: .leading)

            if answersHidden && gameState.mode == .daily {
                Text("•••••")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(.quordleSecondaryText.opacity(0.4))
            } else {
                Text(board.targetWord)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .tracking(1)
                    .foregroundColor(.quordlePrimaryText)
            }

            Spacer(minLength: 4)

            if board.isSolved {
                Text("\(board.solvedAtGuess ?? 0)")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(.quordlePrimary)
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        // Share is a daily-edition feature, hidden on a replay — only the day's first
        // play can be shared. The Solve Report stays available on replays (it shows
        // this replay's analysis). Unlimited has neither.
        let isReplay = viewModel?.isDailyReplay ?? false
        let canShare = gameState.mode == .daily && !isReplay
        let canReport = gameState.mode == .daily && viewModel != nil
        return VStack(spacing: 12) {
            if canShare {
                shareButton.buttonStyle(PrimaryButtonStyle())
            }

            // Solve Report is computed lazily and cached, so opening/re-opening it
            // never recomputes. Promote it to primary when there's no Share (replay).
            if canReport {
                if canShare {
                    viewSolveReportButton.buttonStyle(SecondaryButtonStyle())
                } else {
                    viewSolveReportButton.buttonStyle(PrimaryButtonStyle())
                }
            }

            // Let the player go back and study their board for as long as they like.
            if onReviewBoard != nil {
                if canShare || canReport {
                    viewBoardButton.buttonStyle(SecondaryButtonStyle())
                } else {
                    viewBoardButton.buttonStyle(PrimaryButtonStyle())
                }
            }

            // Done is primary only when nothing above it already claimed that role.
            if canShare || canReport || onReviewBoard != nil {
                doneButton.buttonStyle(SecondaryButtonStyle())
            } else {
                doneButton.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var shareButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            AnalyticsService.logShareResult(gameState: gameState)
            generateAndShare()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Result")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var viewSolveReportButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            showSolveReport = true
        } label: {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                Text("View Solve Report")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var viewBoardButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            onReviewBoard?()
        } label: {
            HStack {
                Image(systemName: "square.grid.2x2")
                Text("View Board")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var doneButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            let leave = onDone ?? { dismiss() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                leave()
            }
        } label: {
            Text("Done")
                .frame(maxWidth: .infinity)
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
