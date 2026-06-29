import SwiftUI

/// Daily challenge main view — "front page" of the daily edition.
struct DailyView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService

    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @State private var showGame = false
    @State private var showArchive = false
    @State private var isReplaying = false
    @State private var savedState: GameState?
    @State private var showSolveReport = false
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Group {
                if dailyPuzzleService.isTodayCompleted && !isReplaying {
                    completedView
                } else {
                    startView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.quordleBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
            .navigationDestination(isPresented: $showArchive) {
                ArchiveCalendarView()
                    .environmentObject(themeService)
                    .environmentObject(statsService)
                    .environmentObject(subscriptionService)
            }
            .onChange(of: showGame) { newValue in
                if !newValue {
                    isReplaying = false
                    savedState = statsService.loadDailyState()
                }
            }
            .sheet(isPresented: $showSolveReport) {
                if let completed = statsService.loadCompletedDailyResult() {
                    NavigationStack {
                        StandaloneSolveReportView(gameState: completed, puzzleNumber: dailyPuzzleService.puzzleNumber)
                    }
                }
            }
            .sheet(isPresented: $showResult) {
                if let completed = statsService.loadCompletedDailyResult() {
                    GameResultView(gameState: completed)
                }
            }
        }
    }

    // MARK: - Masthead

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d yyyy"
        return f.string(from: Date())
    }

    private var masthead: some View {
        VStack(spacing: 0) {
            Text(dateLine)
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .padding(.bottom, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            Text("Octordle")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .padding(.vertical, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            Text("No. \(dailyPuzzleService.puzzleNumber)  ·  Eight Words  ·  Daily")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var countdownFooter: some View {
        VStack(spacing: 14) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1).padding(.horizontal, 24)

            Button {
                HapticManager.shared.buttonTap()
                showArchive = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Past Editions")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .tracking(0.5)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.quordlePrimary)
                .padding(.horizontal, 26)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.quordlePrimary.opacity(0.45), lineWidth: 1.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(spacing: 4) {
                Text("Next Edition In")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                Text(dailyPuzzleService.countdownString)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .monospacedDigit()
            }
            .padding(.bottom, 18)
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 0) {
            masthead
            Spacer()
            VStack(spacing: 22) {
                Text("Today's Edition")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)

                VStack(spacing: 2) {
                    Text("Eight words.")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                    Text("Thirteen guesses.")
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .italic()
                }
                .foregroundColor(.quordlePrimaryText)
                .multilineTextAlignment(.center)

                Button {
                    HapticManager.shared.gameStart()
                    showGame = true
                } label: {
                    Text(savedState != nil ? "Resume Today's Puzzle" : "Begin Today's Puzzle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)

                if statsService.currentStreak >= 1 {
                    let active = dailyPuzzleService.isTodayCompleted
                    Text("— a \(statsService.currentStreak)-day streak —")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(active ? .quordleOrange : .quordleSecondaryText)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            countdownFooter
        }
        .padding(.bottom, 100)
        .iPadReadableWidth()
    }

    // MARK: - Completed View

    private var completedView: some View {
        let completed = statsService.loadCompletedDailyResult()
        let solved = completed?.boards.filter { $0.isSolved }.count ?? 0
        let total = completed?.boards.count ?? 8
        let guesses = completed?.guessCount ?? 0
        let secs = completed?.elapsedSeconds ?? 0
        let timeStr = String(format: "%d:%02d", secs / 60, secs % 60)
        let stars = completed?.starRating ?? 0

        return VStack(spacing: 0) {
            masthead
            Spacer()
            VStack(spacing: 18) {
                Text("SOLVED")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .tracking(3)
                    .foregroundColor(.quordlePrimary)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.quordlePrimary, lineWidth: 2.5))
                    .rotationEffect(.degrees(-7))
                    .opacity(solved == total ? 1 : 0)        // only stamp a full solve

                if solved != total {
                    Text("Edition Closed")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(solved)").font(.system(size: 56, weight: .bold, design: .serif))
                    Text("/ \(total)").font(.system(size: 24, design: .serif)).foregroundColor(.quordleSecondaryText)
                }
                .foregroundColor(.quordlePrimaryText)

                if stars > 0 {
                    HStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < stars ? "star.fill" : "star")
                                .font(.system(size: 13))
                                .foregroundColor(i < stars ? .quordleGold : .quordleSecondaryText.opacity(0.4))
                        }
                    }
                }

                Text("\(guesses) guesses  ·  \(timeStr)")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.quordleSecondaryText)

                Button {
                    HapticManager.shared.buttonTap()
                    showSolveReport = true
                } label: {
                    Text("Read your Solve Report")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)

                Button {
                    HapticManager.shared.buttonTap()
                    showResult = true
                } label: {
                    Text("View result & share")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.quordlePrimary)
                        .underline()
                }

                Button {
                    HapticManager.shared.gameStart()
                    isReplaying = true
                    savedState = nil
                    showGame = true
                } label: {
                    Text("Play again")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                        .underline()
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            countdownFooter
        }
        .padding(.bottom, 100)
        .iPadReadableWidth()
    }
}

#Preview {
    DailyView()
        .environmentObject(ThemeService.shared)
        .environmentObject(StatsService.shared)
        .environmentObject(SubscriptionService.shared)
}
