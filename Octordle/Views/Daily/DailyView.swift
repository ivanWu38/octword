import SwiftUI

/// Daily challenge main view - shows start screen first, navigates to GameView
struct DailyView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService

    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @State private var showGame = false
    @State private var isReplaying = false
    @State private var savedState: GameState?
    @State private var showDailyResult = false

    var body: some View {
        NavigationStack {
            Group {
                if dailyPuzzleService.isTodayCompleted && !isReplaying {
                    completedView
                } else {
                    startView
                }
            }
            .background(LinearGradient.quordleBackground.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                let state = statsService.loadDailyState()
                if let state = state, state.isGameOver {
                    statsService.clearDailyState()
                    savedState = nil
                } else {
                    savedState = state
                }
            }
            .navigationDestination(isPresented: $showGame) {
                if let state = savedState {
                    GameView(resuming: state)
                } else {
                    GameView(mode: .daily, difficulty: Constants.Game.defaultDifficulty)
                }
            }
            .onChange(of: showGame) { newValue in
                if !newValue {
                    isReplaying = false
                    savedState = statsService.loadDailyState()
                }
            }
        }
    }

    // MARK: - Start View

    private var startView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Calendar icon
                ZStack {
                    Circle()
                        .fill(Color.quordlePrimary.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "calendar")
                        .font(.system(size: 56))
                        .foregroundColor(.quordlePrimary)
                }

                // Title
                VStack(spacing: 8) {
                    Text("Daily Challenge")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)

                    Text("Puzzle #\(dailyPuzzleService.puzzleNumber)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.quordleSecondaryText)
                }

                // Streak badge (only show if streak >= 1)
                // Dimmed when today's puzzle hasn't been completed yet
                if statsService.currentStreak >= 1 {
                    let isActive = dailyPuzzleService.isTodayCompleted
                    let flameColor: Color = isActive ? .quordleOrange : .quordleOrange.opacity(0.4)
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(flameColor)
                        Text("\(statsService.currentStreak)-day streak")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(flameColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.quordleOrange.opacity(isActive ? 0.12 : 0.06))
                    )
                }

                // Info card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.quordleSecondary)
                        Text("8 Words to Solve")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.quordlePrimaryText)
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.quordleOrange)
                        Text("13 Guesses Available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.quordlePrimaryText)
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.quordleGold)
                        Text("New puzzle every day")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.quordlePrimaryText)
                        Spacer()
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.quordleCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.quordleCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 4)

                Spacer().frame(height: 20)

                // Play button
                Button {
                    HapticManager.shared.gameStart()
                    if savedState == nil {
                        // No saved state — start fresh
                    }
                    showGame = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: savedState != nil ? "arrow.clockwise" : "play.fill")
                            .font(.system(size: 20))
                        Text(savedState != nil ? "Resume" : "Play Now")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.quordleButtonGradient)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
            .iPadReadableWidth()
        }
    }

    // MARK: - Completed View

    private var completedView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.quordleSuccess.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.quordleSuccess)
                }

                // Title
                VStack(spacing: 8) {
                    Text("Completed!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)

                    Text("Puzzle #\(dailyPuzzleService.puzzleNumber)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.quordleSecondaryText)
                }

                // Stats card
                statsCard

                // Today's result review card
                if let completedState = statsService.loadCompletedDailyResult() {
                    todayResultCard(
                        starRating: completedState.starRating,
                        solvedCount: completedState.boards.filter { $0.isSolved }.count,
                        totalBoards: completedState.boards.count,
                        guessCount: completedState.guessCount,
                        elapsedSeconds: completedState.elapsedSeconds
                    )
                }

                // Countdown card
                countdownCard

                // Replay button
                Button {
                    HapticManager.shared.gameStart()
                    isReplaying = true
                    savedState = nil
                    showGame = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18))
                        Text("Play Again")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.quordlePrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.quordleCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quordlePrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 4)

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
            .iPadReadableWidth()
        }
        .sheet(isPresented: $showDailyResult) {
            if let completedState = statsService.loadCompletedDailyResult() {
                GameResultView(gameState: completedState)
            }
        }
    }

    // MARK: - Today's Result Card

    private func todayResultCard(
        starRating: Int,
        solvedCount: Int,
        totalBoards: Int,
        guessCount: Int,
        elapsedSeconds: Int
    ) -> some View {
        let timeString = String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)

        return Button {
            HapticManager.shared.buttonTap()
            showDailyResult = true
        } label: {
            HStack(spacing: 16) {
                // Star & score
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Image(systemName: index < starRating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(index < starRating ? .quordleGold : .quordleSecondaryText.opacity(0.3))
                        }
                    }

                    Text("\(solvedCount)/\(totalBoards)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                }

                // Divider
                Rectangle()
                    .fill(Color.quordleCardBorder)
                    .frame(width: 1, height: 40)

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Result")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)

                    HStack(spacing: 12) {
                        Label("\(guessCount) guesses", systemImage: "number")
                        Label(timeString, systemImage: "clock")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.quordleSecondaryText.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundColor(dailyPuzzleService.isTodayCompleted ? .quordleOrange : .quordleOrange.opacity(0.4))

                Text("Current Streak")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)

                Spacer()

                Text("\(statsService.currentStreak) \(statsService.currentStreak == 1 ? "day" : "days")")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)
            }

            Divider().background(Color.quordleCardBorder)

            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.quordleGold)

                Text("Total Wins")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)

                Spacer()

                Text("\(statsService.totalWins)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.quordleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.quordleCardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Countdown Card

    private var countdownCard: some View {
        VStack(spacing: 12) {
            Text("Next Puzzle In")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.quordleSecondaryText)

            Text(dailyPuzzleService.countdownString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
                .monospacedDigit()
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.quordleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.quordleCardBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    DailyView()
        .environmentObject(ThemeService.shared)
        .environmentObject(StatsService.shared)
        .environmentObject(SubscriptionService.shared)
}
