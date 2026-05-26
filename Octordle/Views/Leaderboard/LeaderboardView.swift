import SwiftUI

/// Daily leaderboard tab, backed by Game Center.
/// Replaces the former Unlimited/Practice tab.
struct LeaderboardView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var gameCenter: GameCenterService
    @ObservedObject private var dailyService = DailyPuzzleService.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    switch gameCenter.loadState {
                    case .notAuthenticated:
                        signInCard
                    case .loading:
                        loadingCard
                    case .failed:
                        errorCard
                    case .loaded:
                        loadedContent
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .iPadReadableWidth()
            }
            .background(LinearGradient.quordleBackground.ignoresSafeArea())
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await gameCenter.loadLeaderboard()
            }
            .task {
                if gameCenter.isAuthenticated {
                    await gameCenter.loadLeaderboard()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.quordlePrimary.opacity(0.15))
                    .frame(width: 110, height: 110)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.quordlePrimary)
            }

            VStack(spacing: 4) {
                Text("Daily Leaderboard")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)

                Text("Puzzle #\(dailyService.puzzleNumber) · resets in \(dailyService.countdownString)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)
            }
        }
    }

    // MARK: - Loaded content

    @ViewBuilder
    private var loadedContent: some View {
        heroCard

        if !gameCenter.topRows.isEmpty {
            rankingList
        } else if gameCenter.localRow != nil {
            // Score is posted but the global ranking list hasn't synced yet
            // (common in the Game Center sandbox).
            infoCard(
                icon: "checkmark.circle",
                title: "Your score is in!",
                subtitle: "Full rankings will appear once more players have posted today."
            )
        } else {
            emptyBoardCard
        }
    }

    /// Big "you beat X%" card, or a prompt to play today's puzzle.
    private var heroCard: some View {
        VStack(spacing: 8) {
            if let local = gameCenter.localRow {
                if let percentile = gameCenter.percentileBeaten {
                    Text("You beat \(percentile)% of players")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Your score is posted!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    if local.rank > 0 {
                        scorePill(value: "#\(local.rank)", label: "Rank")
                    }
                    scorePill(value: "\(local.boardsSolved)/\(Constants.GameCenter.boardCount)", label: "Solved")
                    scorePill(value: "\(local.guessTotal)", label: "Guesses")
                }
                .padding(.top, 4)
            } else {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32))
                    .foregroundColor(.quordleSecondary)
                Text("Play today's puzzle to join the leaderboard")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)
                if gameCenter.totalPlayers > 0 {
                    Text("\(gameCenter.totalPlayers) players have posted a score today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.quordleSecondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }

    private func scorePill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimary)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ranking list

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Players")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(gameCenter.topRows.enumerated()), id: \.element.id) { index, row in
                    rankRow(row)
                    if index < gameCenter.topRows.count - 1 {
                        Divider().background(Color.quordleCardBorder)
                    }
                }

                // Show the local player below the top list if they're not already in it.
                if let local = gameCenter.localRow,
                   !gameCenter.topRows.contains(where: { $0.isLocalPlayer }) {
                    Divider().background(Color.quordleCardBorder)
                    rankRow(local)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.quordleCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.quordleCardBorder, lineWidth: 1)
            )
        }
    }

    private func rankRow(_ row: LeaderboardRow) -> some View {
        HStack(spacing: 14) {
            Text("\(row.rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(row.isLocalPlayer ? .quordlePrimary : .quordleSecondaryText)
                .frame(width: 32, alignment: .leading)

            Text(row.displayName)
                .font(.system(size: 16, weight: row.isLocalPlayer ? .bold : .medium))
                .foregroundColor(.quordlePrimaryText)
                .lineLimit(1)

            Spacer()

            Text("\(row.boardsSolved)/\(Constants.GameCenter.boardCount) · \(row.guessTotal)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.quordleSecondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(row.isLocalPlayer ? Color.quordlePrimary.opacity(0.08) : Color.clear)
    }

    private var emptyBoardCard: some View {
        infoCard(icon: "person.3", title: "No scores yet today", subtitle: "Be the first to post a score!")
    }

    // MARK: - State cards

    private var signInCard: some View {
        VStack(spacing: 16) {
            infoCard(
                icon: "gamecontroller.fill",
                title: "Sign in to Game Center",
                subtitle: "Compete on the daily leaderboard and see how you rank against players worldwide."
            )
            Button {
                gameCenter.authenticate()
            } label: {
                Text("Sign In")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.quordleButtonGradient)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading leaderboard…")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var errorCard: some View {
        VStack(spacing: 16) {
            infoCard(
                icon: "exclamationmark.triangle",
                title: "Couldn't load leaderboard",
                subtitle: "Check your connection and try again."
            )
            Button {
                Task { await gameCenter.loadLeaderboard() }
            } label: {
                Text("Retry")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.quordleButtonGradient)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func infoCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.quordleSecondary)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(ThemeService.shared)
        .environmentObject(GameCenterService.shared)
}
