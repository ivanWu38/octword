import SwiftUI

/// Daily challenge main view — "front page" of the daily edition.
struct DailyView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService

    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @ObservedObject private var supportService = SupportService.shared
    @ObservedObject private var gameCenter = GameCenterService.shared
    @State private var dailyRank: Int?
    @State private var showDailyRank = false
    @State private var showGame = false
    @State private var showArchive = false
    @State private var isReplaying = false
    @State private var savedState: GameState?
    /// Today's finished game, held in state instead of being re-read from disk.
    /// `completedView` used to call `loadCompletedDailyResult()` straight from its
    /// body — a UserDefaults read plus a full 8-board JSON decode on every redraw.
    @State private var completedResult: GameState?
    @State private var showSolveReport = false
    @State private var showResult = false
    @State private var showSettings = false
    @State private var showSupporter = false
    @State private var isBuyingCoffee = false
    @State private var showCoffeeThanks = false

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
                completedResult = statsService.loadCompletedDailyResult()
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
                    completedResult = statsService.loadCompletedDailyResult()
                }
            }
            .onChange(of: dailyPuzzleService.isTodayCompleted) { _ in
                completedResult = statsService.loadCompletedDailyResult()
            }
            .sheet(isPresented: $showSolveReport) {
                if let completed = completedResult {
                    NavigationStack {
                        StandaloneSolveReportView(gameState: completed, puzzleNumber: dailyPuzzleService.puzzleNumber)
                    }
                }
            }
            .sheet(isPresented: $showResult) {
                if let completed = completedResult {
                    GameResultView(gameState: completed)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSupporter) {
                SupporterView()
            }
            .sheet(isPresented: $showDailyRank) {
                DailyRankView().presentationDragIndicator(.visible)
            }
            .task { await refreshDailyRank() }
            .onChange(of: showDailyRank) { showing in
                if !showing { Task { await refreshDailyRank() } }
            }
            .onChange(of: gameCenter.isAuthenticated) { _ in
                Task { await refreshDailyRank() }
            }
            .overlay {
                if showCoffeeThanks {
                    CoffeeThanksOverlay(count: supportService.coffeeCount) {
                        showCoffeeThanks = false
                    }
                }
            }
        }
    }

    // MARK: - Support flow (inline card on the completed screen)

    private func buyCoffeeFromCard() {
        guard !isBuyingCoffee else { return }
        isBuyingCoffee = true
        Task {
            let earned = await supportService.buyCoffee()
            isBuyingCoffee = false
            if earned {
                HapticManager.shared.celebrateSilently()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showCoffeeThanks = true
                }
            }
        }
    }

    // MARK: - Daily Rank

    /// Today's rank, refreshed whenever the screen appears or the sheet closes.
    /// Deliberately keeps only the rank — never the player total, which is the
    /// weakest number this board has while the app is young.
    private func refreshDailyRank() async {
        dailyRank = await gameCenter.loadLocalDailyRank()?.rank
    }

    private var dailyRankSubtitle: String {
        if !gameCenter.isAuthenticated { return "Tap to join the ranking" }
        if let rank = dailyRank { return "You're #\(rank) today" }
        return "See how you rank today"
    }

    /// Ruled row above the countdown — the leading mark becomes the rank once known.
    private var dailyRankRow: some View {
        Button {
            HapticManager.shared.cardTap()
            showDailyRank = true
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let rank = dailyRank, gameCenter.isAuthenticated {
                        Text("#\(rank)")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(.quordlePrimary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    } else {
                        Text("✦")
                            .font(.system(size: 19))
                            .foregroundColor(.quordleGold)
                    }
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Rank")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(dailyRankSubtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 2)
            .background(dailyRank != nil ? Color.quordlePrimary.opacity(0.05) : Color.clear)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
        .padding(.horizontal, 20)
    }

    // MARK: - Masthead

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d yyyy"
        return f.string(from: Date())
    }

    private var masthead: some View {
        EditorialMasthead(
            kicker: dateLine,
            title: "Octors",
            subtitle: "No. \(dailyPuzzleService.puzzleNumber) · Eight Words · Daily",
            showCoffee: !subscriptionService.isPremium,
            coffeeCount: supportService.coffeeCount,
            onCoffee: { showSupporter = true },
            onSettings: { showSettings = true }
        )
    }

    private var countdownFooter: some View {
        // No leading rule here — the Daily Rank row directly above already closes
        // with one, and two hairlines a few points apart read as a mistake.
        VStack(spacing: 14) {
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
                CountdownText()
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
            dailyRankRow
                .padding(.bottom, 14)
            countdownFooter
        }
        .padding(.bottom, 100)
        .iPadReadableWidth()
    }

    // MARK: - Completed View

    private var completedView: some View {
        let completed = completedResult
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
            dailyRankRow
                .padding(.bottom, 14)
            if supportService.shouldShowCard(isPremium: subscriptionService.isPremium, totalGamesPlayed: statsService.totalGamesPlayed) {
                SupportCard(
                    onSupport: { buyCoffeeFromCard() },
                    onDismiss: { supportService.dismissCardForToday() }
                )
                .padding(.bottom, 18)
            }
            countdownFooter
        }
        .padding(.bottom, 100)
        .iPadReadableWidth()
    }
}

/// The one view that observes the per-second countdown, so the tick redraws a
/// single label instead of the whole screen.
private struct CountdownText: View {
    @ObservedObject private var countdown = EditionCountdown.shared

    var body: some View {
        Text(countdown.text)
            .font(.system(size: 30, weight: .semibold, design: .serif))
            .foregroundColor(.quordlePrimaryText)
            .monospacedDigit()
    }
}

#Preview {
    DailyView()
        .environmentObject(ThemeService.shared)
        .environmentObject(StatsService.shared)
        .environmentObject(SubscriptionService.shared)
}
