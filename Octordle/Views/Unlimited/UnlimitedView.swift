import SwiftUI

/// Unlimited practice hub — pick a difficulty and play as many games as you like.
/// Mirrors the daily edition's masthead styling, but every game is a fresh random
/// puzzle that leaves no trace on The Record.
struct UnlimitedView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService

    @ObservedObject private var supportService = SupportService.shared
    @State private var showGame = false
    @State private var selectedDifficulty: Difficulty = .unlimitedNormal
    @State private var showSettings = false
    @State private var showSupporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                masthead

                Spacer(minLength: 12)

                VStack(spacing: 18) {
                    Text("Choose your challenge")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(.quordleSecondaryText)

                    VStack(spacing: 14) {
                        ForEach(Difficulty.unlimitedCases) { difficulty in
                            difficultyCard(difficulty)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 12)

                Text("Practice freely — results are not recorded.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.bottom, 24)
            }
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.quordleBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .iPadReadableWidth()
            .navigationDestination(isPresented: $showGame) {
                GameView(mode: .unlimited, difficulty: selectedDifficulty)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSupporter) {
                SupporterView()
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        EditorialMasthead(
            kicker: "No Limits · Play On",
            title: "Unlimited",
            subtitle: "Eight Words · Three Modes",
            showCoffee: !subscriptionService.isPremium,
            coffeeCount: supportService.coffeeCount,
            onCoffee: { showSupporter = true },
            onSettings: { showSettings = true }
        )
    }

    // MARK: - Difficulty Card

    private func difficultyCard(_ difficulty: Difficulty) -> some View {
        Button {
            HapticManager.shared.gameStart()
            selectedDifficulty = difficulty
            showGame = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.quordlePrimary.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: difficulty.iconName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.quordlePrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(difficulty.displayName)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(difficulty.description)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.quordleSecondaryText.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }
}

#Preview {
    UnlimitedView()
        .environmentObject(ThemeService.shared)
        .environmentObject(SubscriptionService.shared)
}
