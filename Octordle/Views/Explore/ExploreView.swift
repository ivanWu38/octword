import SwiftUI

/// Explore hub — home of Categories and Challenges, editorial "Daily Edition" styling.
struct ExploreView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @ObservedObject private var categoryService = CategoryService.shared
    @ObservedObject private var supportService = SupportService.shared
    @State private var showSettings = false
    @State private var showSupporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                EditorialMasthead(
                    kicker: "Beyond the Daily",
                    title: "Explore",
                    subtitle: "Categories · Challenges",
                    showCoffee: !subscriptionService.isPremium,
                    coffeeCount: supportService.coffeeCount,
                    onCoffee: { showSupporter = true },
                    onSettings: { showSettings = true }
                )
                .iPadReadableWidth(520)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        sectionLabel("Categories")
                        categoriesCard

                        sectionLabel("Challenges")
                        challengesCard

                        sectionLabel("Subscription")
                        PremiumEntryCard(source: "explore")
                            .padding(.horizontal, 24)

                        Spacer().frame(height: 110)
                    }
                    .iPadReadableWidth(520)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.quordleBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView().presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSupporter) {
                SupporterView()
            }
        }
    }

    // MARK: - Sections

    private func sectionLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 14)
    }

    private var categoriesCard: some View {
        NavigationLink {
            CategoriesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.quordlePrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Themed Word Packs")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(categoriesSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(16)
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
        .simultaneousGesture(TapGesture().onEnded { HapticManager.shared.cardTap() })
        .padding(.horizontal, 24)
    }

    private var categoriesSubtitle: String {
        let progress = categoryService.overallProgress
        guard progress.total > 0 else { return "Animals, Food, Travel and more" }
        return "\(categoryService.categories.count) packs · \(progress.solved)/\(progress.total) solved"
    }

    private var challengesCard: some View {
        NavigationLink {
            ChallengesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.quordlePrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Timed & Run")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(challengesSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.quordleSecondaryText)
            }
            .padding(16)
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
        .simultaneousGesture(TapGesture().onEnded { HapticManager.shared.cardTap() })
        .padding(.horizontal, 24)
    }

    private var challengesSubtitle: String {
        let best = ChallengeType.all
            .map { ChallengeSession.loadBest(for: $0.id) }
            .max() ?? 0
        return best > 0
            ? "Beat the clock or survive — best run \(best) solved"
            : "Beat the clock, or survive as long as you can"
    }
}

#Preview {
    ExploreView()
        .environmentObject(ThemeService.shared)
        .environmentObject(StatsService.shared)
        .environmentObject(SubscriptionService.shared)
}
