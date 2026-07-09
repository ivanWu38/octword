import SwiftUI

/// Themed word-pack list — editorial "Daily Edition" styling.
/// Free packs and today's rotating pack open directly; locked packs offer
/// Pro or a rewarded ad for a single puzzle.
struct CategoriesView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @ObservedObject private var categoryService = CategoryService.shared
    @ObservedObject private var rewardedAd = RewardedAdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var openedCategory: WordCategory?
    @State private var showDetail = false
    @State private var lockedCategory: WordCategory?
    @State private var showLockedDialog = false
    @State private var showPaywall = false
    @State private var adGameCategory: WordCategory?
    @State private var adGameIndex = 0
    @State private var showAdGame = false
    @State private var isShowingAd = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header

                VStack(spacing: 12) {
                    ForEach(categoryService.categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer().frame(height: 110)
            }
            .iPadReadableWidth(520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showDetail) {
            if let category = openedCategory {
                CategoryDetailView(category: category)
            }
        }
        .navigationDestination(isPresented: $showAdGame) {
            if let category = adGameCategory {
                GameView(category: category, puzzleIndex: adGameIndex)
            }
        }
        .sheet(isPresented: $showPaywall) { SubscriptionView() }
        .confirmationDialog(
            lockedCategory.map { "\($0.name) is a Pro pack" } ?? "",
            isPresented: $showLockedDialog,
            titleVisibility: .visible
        ) {
            Button("Unlock everything with Pro") { showPaywall = true }
            Button("Watch an ad · play one puzzle") { startAdUnlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A different Pro pack is free to play every day.")
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
        let unlocked = categoryService.isUnlocked(category, isPremium: subscriptionService.isPremium)
        let isTodayFree = !category.free && category.id == categoryService.dailyFreeCategoryId
        let done = categoryService.completedCount(categoryId: category.id)

        return Button {
            HapticManager.shared.buttonTap()
            if unlocked {
                openedCategory = category
                showDetail = true
            } else {
                lockedCategory = category
                showLockedDialog = true
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: category.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(unlocked ? .quordlePrimary : .quordleSecondaryText)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(.quordlePrimaryText)
                        if isTodayFree {
                            Text("Free Today")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundColor(.quordleGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(Color.quordleGold, lineWidth: 1))
                        }
                    }
                    Text("\(done) / \(category.puzzleCount) solved")
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                if unlocked {
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
                            .stroke(isTodayFree ? Color.quordleGold.opacity(0.6) : Color.quordleCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }

    // MARK: - Rewarded ad unlock

    private func startAdUnlock() {
        guard let category = lockedCategory else { return }
        let index = categoryService.nextUnsolvedIndex(in: category)
        isShowingAd = true
        Task {
            let rewarded = await rewardedAd.showAd()
            isShowingAd = false
            if rewarded {
                categoryService.grantAdUnlock(categoryId: category.id, puzzleIndex: index)
                adGameCategory = category
                adGameIndex = index
                showAdGame = true
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
