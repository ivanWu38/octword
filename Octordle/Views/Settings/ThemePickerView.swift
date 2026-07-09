import SwiftUI

/// Theme picker view with live preview and unlock progress
struct ThemePickerView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var statsService: StatsService

    @State private var previewTheme: BoardTheme? = nil
    @State private var showSubscription = false

    private var wordsSolved: Int { statsService.totalWordsSolved }
    private var maxStreak: Int { statsService.maxStreak }
    private var isPremium: Bool { subscriptionService.isPremium }

    private var displayedTheme: BoardTheme {
        previewTheme ?? themeService.selectedTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed preview at top
            previewSection
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Fixed action button
            actionButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Scrollable theme list
            ScrollView {
                VStack(spacing: 10) {
                    // Free
                    sectionHeader("Free", icon: "star.fill", color: .quordlePrimary)
                    ForEach(BoardTheme.freeThemes) { theme in
                        themeCard(theme: theme)
                    }

                    // Words-solved rewards
                    sectionHeader("Words Solved", icon: "textformat.abc", color: .quordleGold)
                    ForEach(BoardTheme.wordsThemes) { theme in
                        themeCard(theme: theme)
                    }

                    // Streak rewards
                    sectionHeader("Streak Rewards", icon: "flame.fill", color: .quordleOrange)
                    ForEach(BoardTheme.streakThemes) { theme in
                        themeCard(theme: theme)
                    }

                    // Premium
                    sectionHeader("Premium", icon: "crown.fill", color: .quordleSecondary)
                    ForEach(BoardTheme.premiumThemes) { theme in
                        themeCard(theme: theme)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Theme")
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                previewTile(letter: "S", state: .correct)
                previewTile(letter: "T", state: .present)
                previewTile(letter: "A", state: .absent)
                previewTile(letter: "R", state: .empty)
                previewTile(letter: "S", state: .empty)
            }

            Text(displayedTheme.displayName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)

            HStack(spacing: 16) {
                legendItem(color: displayedTheme.correctColor, label: "Correct")
                legendItem(color: displayedTheme.presentColor, label: "Present")
                legendItem(color: displayedTheme.absentColor, label: "Absent")
            }
            .font(.caption)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func previewTile(letter: String, state: PreviewTileState) -> some View {
        let size: CGFloat = 48
        return Text(letter)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(state == .empty ? .quordlePrimaryText : .white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(tileColor(for: state))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(tileBorder(for: state), lineWidth: state == .empty ? 2 : 0)
            )
            .animation(.easeInOut(duration: 0.2), value: displayedTheme)
    }

    private func tileColor(for state: PreviewTileState) -> Color {
        switch state {
        case .correct: return displayedTheme.correctColor
        case .present: return displayedTheme.presentColor
        case .absent: return displayedTheme.absentColor
        case .empty: return displayedTheme.emptyColor
        }
    }

    private func tileBorder(for state: PreviewTileState) -> Color {
        state == .empty ? displayedTheme.emptyBorderColor : .clear
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundColor(.quordleSecondaryText)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        let theme = displayedTheme
        let isCurrentTheme = theme == themeService.selectedTheme
        let unlocked = theme.isUnlocked(isPremium: isPremium, wordsSolved: wordsSolved, maxStreak: maxStreak)

        if isCurrentTheme {
            // Currently applied
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Current Theme")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.quordleSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.regularMaterial)
            )
        } else if unlocked {
            // Unlocked → Apply
            Button {
                HapticManager.shared.primaryTap()
                AnalyticsService.logThemeSelected(themeId: theme.rawValue)
                themeService.selectedTheme = theme
                previewTheme = nil
            } label: {
                Text("Apply Theme")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.quordlePrimary, .quordleSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .quordlePrimary.opacity(0.3), radius: 8, y: 3)
                    )
            }
        } else if theme.isPremium {
            // Premium locked
            Button {
                HapticManager.shared.primaryTap()
                showSubscription = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Unlock with Premium")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.quordleGold, .quordleOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .quordleGold.opacity(0.3), radius: 8, y: 3)
                )
            }
        } else {
            // Wins or streak locked → show progress
            unlockProgressView(for: theme)
        }
    }

    @ViewBuilder
    private func unlockProgressView(for theme: BoardTheme) -> some View {
        switch theme.unlockType {
        case .words(let required):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 14))
                        .foregroundColor(.quordleGold)
                    Text("Solve \(required) words to unlock")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.quordleSecondaryText.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.quordleGold, .quordleOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(CGFloat(wordsSolved) / CGFloat(required), 1.0))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                Text("\(wordsSolved) / \(required)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )

        case .streak(let required):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.quordleOrange)
                    Text("Reach a \(required)-day streak to unlock")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.quordlePrimaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.quordleSecondaryText.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.quordleOrange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(CGFloat(maxStreak) / CGFloat(required), 1.0))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                Text("\(maxStreak) / \(required) days")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )

        default:
            EmptyView()
        }
    }

    // MARK: - Theme Card

    private func themeCard(theme: BoardTheme) -> some View {
        let isSelected = themeService.selectedTheme == theme
        let isPreviewing = previewTheme == theme
        let unlocked = theme.isUnlocked(isPremium: isPremium, wordsSolved: wordsSolved, maxStreak: maxStreak)

        return Button {
            HapticManager.shared.cardTap()
            previewTheme = theme
        } label: {
            HStack(spacing: 14) {
                // Color swatches
                HStack(spacing: 4) {
                    Circle()
                        .fill(theme.correctColor)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(theme.presentColor)
                        .frame(width: 24, height: 24)
                }
                .opacity(unlocked ? 1 : 0.4)

                // Name + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(unlocked ? .quordlePrimaryText : .quordleSecondaryText)

                    cardSubtitle(for: theme, unlocked: unlocked)
                }

                Spacer()

                // Status
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.quordlePrimary, .quordleSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else if !unlocked {
                    lockIcon(for: theme)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isPreviewing
                            ? LinearGradient(
                                colors: [.quordlePrimary, .quordleSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cardSubtitle(for theme: BoardTheme, unlocked: Bool) -> some View {
        switch theme.unlockType {
        case .free:
            Text("Default")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
        case .words(let required):
            if unlocked {
                Label("Unlocked", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSuccess)
            } else {
                Text("\(wordsSolved)/\(required) words")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSecondaryText)
            }
        case .streak(let required):
            if unlocked {
                Label("Unlocked", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSuccess)
            } else {
                Text("\(maxStreak)/\(required) days")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSecondaryText)
            }
        case .premium:
            if unlocked {
                Label("Unlocked", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.quordleSuccess)
            } else {
                Text("Premium")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.quordleGold)
            }
        }
    }

    @ViewBuilder
    private func lockIcon(for theme: BoardTheme) -> some View {
        switch theme.unlockType {
        case .words:
            Image(systemName: "textformat.abc")
                .font(.system(size: 15))
                .foregroundColor(.quordleGold.opacity(0.5))
        case .streak:
            Image(systemName: "flame.fill")
                .font(.system(size: 15))
                .foregroundColor(.quordleOrange.opacity(0.5))
        case .premium:
            Image(systemName: "crown.fill")
                .font(.system(size: 15))
                .foregroundColor(.quordleGold.opacity(0.5))
        default:
            EmptyView()
        }
    }
}

/// Preview tile states
private enum PreviewTileState {
    case correct, present, absent, empty
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environmentObject(ThemeService.shared)
            .environmentObject(SubscriptionService.shared)
            .environmentObject(StatsService.shared)
    }
}
