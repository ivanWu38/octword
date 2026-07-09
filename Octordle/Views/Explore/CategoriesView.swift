import SwiftUI

/// Themed word-pack list — editorial "Daily Edition" styling.
/// Free packs and today's rotating pack open directly; locked packs offer
/// Pro or a rewarded ad for a single puzzle.
struct CategoriesView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @ObservedObject private var categoryService = CategoryService.shared
    @ObservedObject private var rewardedAd = RewardedAdManager.category
    @Environment(\.dismiss) private var dismiss

    @State private var openedCategory: WordCategory?
    @State private var showDetail = false
    @State private var lockedCategory: WordCategory?
    @State private var showPaywall = false
    @State private var isShowingAd = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .iPadReadableWidth(520)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(categoryService.categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 110)
                .iPadReadableWidth(520)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showDetail) {
            if let category = openedCategory {
                CategoryDetailView(category: category)
            }
        }
        .sheet(isPresented: $showPaywall) { SubscriptionView() }
        .sheet(item: $lockedCategory) { category in
            LockedPackSheet(
                category: category,
                packCount: categoryService.categories.count,
                onWatchAd: {
                    lockedCategory = nil
                    startAdUnlock(for: category)
                },
                onPremium: {
                    lockedCategory = nil
                    showPaywall = true
                }
            )
            .presentationDetents([.height(440)])
            .presentationDragIndicator(.visible)
        }
        .onAppear { rewardedAd.preloadIfNeeded() }
        .overlay {
            if isShowingAd {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        let progress = categoryService.overallProgress
        return EditorialMasthead(
            kicker: "Themed Word Packs",
            title: "Categories",
            subtitle: "\(progress.solved) of \(progress.total) puzzles solved",
            onBack: { dismiss() }
        )
    }

    // MARK: - Rows

    private func categoryRow(_ category: WordCategory) -> some View {
        let canEnter = categoryService.canEnter(category, isPremium: subscriptionService.isPremium)
        let done = categoryService.completedCount(categoryId: category.id)

        return Button {
            HapticManager.shared.cardTap()
            if canEnter {
                openedCategory = category
                showDetail = true
            } else {
                lockedCategory = category
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: category.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(canEnter ? .quordlePrimary : .quordleSecondaryText)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text("\(done) / \(category.puzzleCount) solved")
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                if canEnter {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                } else {
                    Image(systemName: "lock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(14)
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

    // MARK: - Rewarded ad unlock

    /// Watch a rewarded ad, then unlock the front unsolved level and drop the
    /// player into the pack's level list (where that one level is ready to play).
    private func startAdUnlock(for category: WordCategory) {
        let index = categoryService.nextUnsolvedIndex(in: category)
        isShowingAd = true
        Task {
            let rewarded = await rewardedAd.showAd()
            isShowingAd = false
            if rewarded {
                categoryService.markPackEntered(categoryId: category.id)
                categoryService.grantAdUnlock(categoryId: category.id, puzzleIndex: index)
                openedCategory = category
                showDetail = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
            .environmentObject(ThemeService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}
