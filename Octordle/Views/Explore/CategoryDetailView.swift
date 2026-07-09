import SwiftUI

/// Puzzle picker for one themed pack — numbered chips, solved ones checked off.
/// For a locked (Premium) pack the player can enter after one rewarded ad; inside,
/// each level is unlocked individually — solved levels stay free forever, unsolved
/// locked levels each cost one more ad (or Premium unlocks everything).
struct CategoryDetailView: View {
    let category: WordCategory

    @EnvironmentObject var themeService: ThemeService
    @ObservedObject private var categoryService = CategoryService.shared
    @ObservedObject private var subscriptionService = SubscriptionService.shared
    @ObservedObject private var rewardedAd = RewardedAdManager.category
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIndex = 0
    @State private var showGame = false
    @State private var lockedLevel: LockedLevel?
    @State private var showPaywall = false
    @State private var isShowingAd = false

    /// Wraps a tapped locked level index so it can drive a `.sheet(item:)`.
    private struct LockedLevel: Identifiable { let id: Int }

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    /// Whether the whole pack is open (free pack or Premium user).
    private var packUnlocked: Bool {
        categoryService.isUnlocked(category, isPremium: subscriptionService.isPremium)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .iPadReadableWidth(520)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<category.puzzleCount, id: \.self) { index in
                        puzzleChip(index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 110)
                .iPadReadableWidth(520)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showGame) {
            GameView(category: category, puzzleIndex: selectedIndex)
        }
        .sheet(isPresented: $showPaywall) { SubscriptionView() }
        .sheet(item: $lockedLevel) { level in
            LockedPackSheet(
                category: category,
                packCount: categoryService.categories.count,
                onWatchAd: {
                    lockedLevel = nil
                    startAdUnlock(index: level.id)
                },
                onPremium: {
                    lockedLevel = nil
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
        EditorialMasthead(
            kicker: "Word Pack",
            title: category.name,
            subtitle: "\(categoryService.completedCount(categoryId: category.id)) of \(category.puzzleCount) solved",
            onBack: { dismiss() }
        )
    }

    // MARK: - Chips

    private enum ChipState { case solved, ready, playable, locked }

    private func chipState(_ index: Int) -> ChipState {
        if categoryService.isCompleted(categoryId: category.id, puzzleIndex: index) { return .solved }
        if packUnlocked { return .playable }
        if categoryService.isPuzzlePlayable(category, puzzleIndex: index, isPremium: subscriptionService.isPremium) {
            return .ready
        }
        return .locked
    }

    private func puzzleChip(_ index: Int) -> some View {
        let state = chipState(index)

        return Button {
            HapticManager.shared.buttonTap()
            switch state {
            case .locked:
                lockedLevel = LockedLevel(id: index)
            default:
                selectedIndex = index
                showGame = true
            }
        } label: {
            VStack(spacing: 5) {
                Text("\(index + 1)")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(numberColor(state))

                icon(state)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(numberColor(state))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .opacity(state == .locked ? 0.62 : 1)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(state == .ready ? Color.quordleGold.opacity(0.12) : Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor(state), lineWidth: state == .ready ? 2 : 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
    }

    private func icon(_ state: ChipState) -> Image {
        switch state {
        case .solved:   return Image(systemName: "checkmark.circle.fill")
        case .ready:    return Image(systemName: "play.circle.fill")
        case .playable: return Image(systemName: "circle.dotted")
        case .locked:   return Image(systemName: "lock.fill")
        }
    }

    private func numberColor(_ state: ChipState) -> Color {
        switch state {
        case .solved:   return .quordleCorrect
        case .ready:    return .quordleGold
        case .playable: return .quordlePrimaryText
        case .locked:   return .quordleSecondaryText
        }
    }

    private func borderColor(_ state: ChipState) -> Color {
        switch state {
        case .solved:   return .quordleCorrect.opacity(0.55)
        case .ready:    return .quordleGold
        default:        return .quordleCardBorder
        }
    }

    // MARK: - Rewarded ad unlock (per level)

    /// Watch a rewarded ad, unlock this one level, then open it right away.
    private func startAdUnlock(index: Int) {
        isShowingAd = true
        Task {
            let rewarded = await rewardedAd.showAd()
            isShowingAd = false
            if rewarded {
                categoryService.grantAdUnlock(categoryId: category.id, puzzleIndex: index)
                selectedIndex = index
                showGame = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: WordCategory(
            id: "animals", name: "Animals", symbol: "pawprint", free: true,
            puzzles: [["HORSE", "ZEBRA", "TIGER", "SNAKE", "MOUSE", "SHEEP", "CAMEL", "OTTER"]]
        ))
        .environmentObject(ThemeService.shared)
    }
}
