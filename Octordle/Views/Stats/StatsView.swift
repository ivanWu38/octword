import SwiftUI

/// Journey — "The Record", an editorial almanac of the player's history.
struct StatsView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @ObservedObject private var supportService = SupportService.shared
    @State private var selectedAchievement: Achievement?
    @State private var showSettings = false
    @State private var showSupporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                masthead
                    .iPadReadableWidth(520)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ledgerSection
                        if statsService.totalWins > 0 {
                            blockLabel("Guess Distribution")
                            guessDistribution
                        }
                        blockLabel("Marks of Distinction",
                                   trailing: "\(statsService.unlockedAchievementsCount) / \(statsService.totalAchievementsCount)")
                        marksSection
                        Spacer().frame(height: 100)
                    }
                    .iPadReadableWidth(520)
                }
            }
            .background(Color.quordleBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { selectedAchievement = nil }
            .onDisappear { selectedAchievement = nil }
            .sheet(isPresented: $showSettings) {
                SettingsView().presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSupporter) {
                SupporterView()
            }
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

    // MARK: - Masthead

    private var masthead: some View {
        EditorialMasthead(
            kicker: "Statistics · Achievements",
            title: "The Record",
            subtitle: "Your Octordle Almanac",
            showCoffee: !subscriptionService.isPremium,
            coffeeCount: supportService.coffeeCount,
            onCoffee: { showSupporter = true },
            onSettings: { showSettings = true }
        )
    }

    private func blockLabel(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 4)
    }

    // MARK: - Ledger

    private var ledgerSection: some View {
        VStack(spacing: 0) {
            LedgerRow(key: "Editions Solved", value: "\(statsService.dailyChallengesCompleted)")
            LedgerRow(key: "Current Streak", value: "\(statsService.currentStreak)")
            LedgerRow(key: "Longest Streak", value: "\(statsService.maxStreak)")
            LedgerRow(key: "Words Solved", value: "\(statsService.totalWordsSolved)")
            LedgerRow(key: "Win Rate", value: statsService.winRateString)
            if statsService.totalWins > 0 {
                LedgerRow(key: "Avg Guesses / Win", value: statsService.averageGuessesString)
            }
            if statsService.perfectGames > 0 {
                LedgerRow(key: "Perfect Editions", value: "\(statsService.perfectGames)")
            }
            if let fastest = statsService.fastestWin {
                LedgerRow(key: "Fastest Solve", value: statsService.formatTime(fastest))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: - Guess Distribution

    private var guessDistribution: some View {
        let distribution = statsService.guessDistribution()
        let sortedKeys = distribution.keys.sorted()
        let maxCount = distribution.values.max() ?? 1
        return VStack(spacing: 8) {
            ForEach(sortedKeys, id: \.self) { guessCount in
                GuessDistributionBar(guessCount: guessCount, count: distribution[guessCount] ?? 0, maxCount: maxCount)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }

    // MARK: - Marks of Distinction

    private var marksSection: some View {
        VStack(spacing: 0) {
            ForEach(Achievement.allCases) { achievement in
                Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
                MarkColumn(
                    achievement: achievement,
                    isUnlocked: statsService.isUnlocked(achievement),
                    progress: statsService.progressFor(achievement)
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedAchievement = achievement }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }
}

// MARK: - Ledger Row (dotted-leader table)

struct LedgerRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .fixedSize()

            GeometryReader { g in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: g.size.height - 3))
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height - 3))
                }
                .stroke(Color.quordleCardBorder, style: StrokeStyle(lineWidth: 1, dash: [1.5, 3]))
            }
            .frame(height: 16)

            Text(value)
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .fixedSize()
        }
        .padding(.vertical, 9)
    }
}

// MARK: - Mark of Distinction (newspaper feature column)

struct MarkColumn: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: (current: Int, required: Int)

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            framedIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(isUnlocked ? .quordlePrimaryText : .quordleSecondaryText)

                Text(achievement.description)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(.quordleSecondaryText)

                progressLine
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    private var framedIcon: some View {
        ZStack {
            Rectangle().fill(Color.quordleCardBackground)
            Rectangle().stroke(isUnlocked ? Color.quordlePrimaryText : Color.quordleCardBorder, lineWidth: 1)
            Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1).padding(3)
            Image(systemName: achievement.iconName)
                .font(.system(size: 20))
                .foregroundColor(isUnlocked ? .quordlePrimary : .quordleSecondaryText.opacity(0.5))
        }
        .frame(width: 54, height: 54)
    }

    @ViewBuilder
    private var progressLine: some View {
        if isUnlocked {
            Text("— Earned —")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordlePrimary)
                .padding(.top, 3)
        } else if progress.required > 1 {
            HStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.quordleCardBorder)
                        Capsule().fill(Color.quordlePrimary)
                            .frame(width: g.size.width * CGFloat(progress.current) / CGFloat(progress.required))
                    }
                }
                .frame(width: 120, height: 4)
                Text("\(progress.current) / \(progress.required)")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(.top, 6)
        } else {
            Text("Locked")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText.opacity(0.6))
                .padding(.top, 3)
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
            Text("\(guessCount)")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 22, alignment: .trailing)

            GeometryReader { geometry in
                let barWidth = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) * geometry.size.width : 0
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(count > 0 ? Color.quordlePrimary : Color.quordleCardBorder)
                        .frame(width: count > 0 ? max(barWidth, 18) : 6)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 18)

            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsService.shared)
        .environmentObject(SubscriptionService.shared)
}
