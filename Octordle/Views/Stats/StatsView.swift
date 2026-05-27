import SwiftUI

/// Statistics view - Zip Game JourneyView style
struct StatsView: View {
    @EnvironmentObject var statsService: StatsService
    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedAchievement: Achievement?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Streak cards (side by side)
                    streakCardsSection

                    // Guess distribution chart
                    if statsService.totalWins > 0 {
                        guessDistributionSection
                    }

                    // Statistics section
                    statisticsSection

                    // Personal bests section
                    personalBestsSection

                    // Fun facts section
                    if statsService.totalGamesPlayed > 0 {
                        funFactsSection
                    }

                    // Achievements section (at bottom)
                    achievementsSection

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .iPadReadableWidth()
            }
            .background(LinearGradient.quordleBackground.ignoresSafeArea())
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if let achievement = selectedAchievement {
                    AchievementDetailView(
                        achievement: achievement,
                        isUnlocked: statsService.isUnlocked(achievement),
                        progress: statsService.progressFor(achievement),
                        onDismiss: { selectedAchievement = nil }
                    )
                }
            }
        }
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(spacing: 16) {
            // Header with progress
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.quordleGold)

                    Text("Achievements")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                }

                Spacer()

                // Progress indicator
                Text("\(statsService.unlockedAchievementsCount)/\(statsService.totalAchievementsCount)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)
            }

            // Achievement grid (2 columns)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Achievement.allCases) { achievement in
                    AchievementBadge(
                        achievement: achievement,
                        isUnlocked: statsService.isUnlocked(achievement),
                        progress: statsService.progressFor(achievement)
                    )
                    .onTapGesture {
                        selectedAchievement = achievement
                    }
                }
            }
        }
    }

    // MARK: - Guess Distribution Section

    private var guessDistributionSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "chart.bar.xaxis", title: "Guess Distribution", color: .quordlePrimary)

            VStack(spacing: 8) {
                let distribution = statsService.guessDistribution()
                let sortedKeys = distribution.keys.sorted()
                let maxCount = distribution.values.max() ?? 1

                ForEach(sortedKeys, id: \.self) { guessCount in
                    GuessDistributionBar(
                        guessCount: guessCount,
                        count: distribution[guessCount] ?? 0,
                        maxCount: maxCount
                    )
                }
            }
            .padding(16)
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

    // MARK: - Top Stats Cards Section

    private var streakCardsSection: some View {
        HStack(spacing: 16) {
            // Words Solved
            StreakCard(
                icon: "textformat.abc",
                iconColor: .quordlePrimary,
                value: statsService.totalWordsSolved,
                label: "Words Solved",
                sublabel: statsService.totalWordsSolved == 1 ? "word" : "words"
            )

            // Current Streak
            // Dimmed when today's puzzle hasn't been completed yet
            StreakCard(
                icon: "flame.fill",
                iconColor: .quordleOrange,
                value: statsService.currentStreak,
                label: "Current Streak",
                sublabel: statsService.currentStreak == 1 ? "day" : "days",
                isActive: dailyPuzzleService.isTodayCompleted
            )
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "chart.bar.fill", title: "Statistics", color: .quordlePrimary)

            VStack(spacing: 0) {
                StatisticRow(label: "Total Wins", value: "\(statsService.totalWins)")
                Divider().background(Color.quordleCardBorder)
                StatisticRow(label: "Win Rate", value: statsService.winRateString)
                Divider().background(Color.quordleCardBorder)
                StatisticRow(label: "Daily Puzzles", value: "\(statsService.dailyChallengesCompleted)")
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

    // MARK: - Personal Bests Section

    private var personalBestsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "medal.fill", title: "Personal Bests", color: .quordleGold)

            VStack(spacing: 12) {
                ForEach(Difficulty.allCases) { difficulty in
                    PersonalBestCard(
                        difficulty: difficulty,
                        bestTime: statsService.bestTime(for: difficulty),
                        bestGuesses: statsService.bestGuesses(for: difficulty),
                        formatTime: statsService.formatTime
                    )
                }
            }
        }
    }

    // MARK: - Fun Facts Section

    private var funFactsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(icon: "sparkles", title: "Highlights", color: .quordleSecondary)

            VStack(spacing: 0) {
                // Fastest win
                if let fastest = statsService.fastestWin {
                    FunFactCard(
                        icon: "bolt.fill",
                        title: "Fastest Win",
                        value: statsService.formatTime(fastest)
                    )
                    Divider().background(Color.quordleCardBorder)
                }

                // Clutch wins
                if statsService.clutchWins > 0 {
                    FunFactCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Clutch Wins",
                        value: "\(statsService.clutchWins)"
                    )
                    Divider().background(Color.quordleCardBorder)
                }

                // Perfect games
                if statsService.perfectGames > 0 {
                    FunFactCard(
                        icon: "star.fill",
                        title: "Perfect Games",
                        value: "\(statsService.perfectGames)"
                    )
                    Divider().background(Color.quordleCardBorder)
                }

                // Average guesses
                if statsService.totalWins > 0 {
                    FunFactCard(
                        icon: "number.circle.fill",
                        title: "Avg Guesses/Win",
                        value: statsService.averageGuessesString
                    )
                    Divider().background(Color.quordleCardBorder)
                }

                // Favorite mode
                if let mostPlayed = statsService.mostPlayedDifficulty {
                    FunFactCard(
                        icon: mostPlayed.iconName,
                        title: "Favorite Mode",
                        value: mostPlayed.displayName
                    )
                    Divider().background(Color.quordleCardBorder)
                }

                // This week activity
                FunFactCard(
                    icon: "calendar.badge.clock",
                    title: "This Week",
                    value: "\(statsService.winsThisWeek)/\(statsService.gamesThisWeek) wins"
                )
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

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)

            Spacer()
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let icon: String
    let iconColor: Color
    let value: Int
    let label: String
    let sublabel: String
    var isActive: Bool = true

    private var effectiveIconColor: Color {
        isActive ? iconColor : iconColor.opacity(0.4)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(effectiveIconColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(effectiveIconColor)
            }

            // Value
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)

            // Label
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSecondaryText)

                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundColor(.quordleSecondaryText.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Statistic Row

struct StatisticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.quordleSecondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Personal Best Card

struct PersonalBestCard: View {
    let difficulty: Difficulty
    let bestTime: Int?
    let bestGuesses: Int?
    let formatTime: (Int) -> String

    var body: some View {
        HStack(spacing: 14) {
            // Difficulty icon
            ZStack {
                Circle()
                    .fill(difficultyColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: difficulty.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(difficultyColor)
            }

            // Single mode now — label the card by what it shows, not the difficulty name
            Text("Best Result")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.quordlePrimaryText)

            Spacer()

            // Stats
            if let time = bestTime, let guesses = bestGuesses {
                HStack(spacing: 16) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(formatTime(time))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.quordleSecondaryText)

                    // Guesses
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 12))
                        Text("\(guesses)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.quordleSecondaryText)
                }
            } else {
                Text("No wins")
                    .font(.system(size: 14))
                    .foregroundColor(.quordleSecondaryText.opacity(0.6))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .relaxed: return .quordleSuccess
        case .classic: return .quordlePrimary
        case .challenge: return .quordleOrange
        case .ultimate: return .red
        }
    }
}

// MARK: - Fun Fact Card

struct FunFactCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.quordleSecondary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.quordleSecondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: (current: Int, required: Int)

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? iconColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: achievement.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(isUnlocked ? iconColor : .gray.opacity(0.4))
            }

            // Title
            Text(achievement.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isUnlocked ? .quordlePrimaryText : .quordleSecondaryText.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Progress or checkmark
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.quordleSuccess)
            } else if progress.required > 1 {
                Text("\(progress.current)/\(progress.required)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText.opacity(0.6))
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? Color.quordleCardBackground : Color.quordleCardBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? iconColor.opacity(0.3) : Color.quordleCardBorder.opacity(0.5), lineWidth: 1)
        )
    }

    private var iconColor: Color {
        switch achievement.iconColor {
        case "gold": return .quordleGold
        case "orange": return .quordleOrange
        case "blue": return .quordlePrimary
        case "purple": return .quordleSecondary
        case "green": return .quordleSuccess
        case "red": return .red
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .quordlePrimary
        }
    }
}

// MARK: - Guess Distribution Bar

struct GuessDistributionBar: View {
    let guessCount: Int
    let count: Int
    let maxCount: Int

    var body: some View {
        HStack(spacing: 8) {
            // Guess number
            Text("\(guessCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 20, alignment: .trailing)

            // Bar
            GeometryReader { geometry in
                let barWidth = maxCount > 0
                    ? CGFloat(count) / CGFloat(maxCount) * geometry.size.width
                    : 0

                HStack {
                    if count > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.quordleAccentGradient)
                            .frame(width: max(barWidth, 24))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 8)
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(height: 24)

            // Count
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsService.shared)
}
