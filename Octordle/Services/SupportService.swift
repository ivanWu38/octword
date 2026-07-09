import Foundation

/// Tracks voluntary "buy me a coffee" support (rewarded-ad gifts) and the gentle
/// invitations to do so. Kept separate from StatsService so its behaviour and
/// reporting stay independent from gameplay stats.
@MainActor
final class SupportService: ObservableObject {
    static let shared = SupportService()

    private let defaults = UserDefaults.standard
    private let coffeeCountKey = "octordle_coffeeCount"
    private let cardDismissedDayKey = "octordle_supportCardDismissedDay"

    /// Total coffees the player has gifted (one per completed rewarded ad).
    @Published private(set) var coffeeCount: Int = 0
    /// The day ("yyyy-MM-dd") the player last dismissed or acted on the support card.
    @Published private(set) var cardDismissedDay: String = ""

    /// Don't invite brand-new players — only ask once they've played a few games first.
    private let minGamesBeforeInviting = 3

    private init() {
        coffeeCount = defaults.integer(forKey: coffeeCountKey)
        cardDismissedDay = defaults.string(forKey: cardDismissedDayKey) ?? ""
    }

    // MARK: - Gentle invitation gating

    /// Whether the soft support card should appear on today's completed screen.
    /// Hidden for premium members (they already support via subscription), for
    /// brand-new players, and once per day after it's been dismissed or acted on.
    func shouldShowCard(isPremium: Bool, totalGamesPlayed: Int) -> Bool {
        guard !isPremium else { return false }
        guard totalGamesPlayed >= minGamesBeforeInviting else { return false }
        return cardDismissedDay != DailyPuzzleService.shared.todayString
    }

    /// Retire the card for the rest of today (no pressure, ask again another day).
    func dismissCardForToday() {
        cardDismissedDay = DailyPuzzleService.shared.todayString
        defaults.set(cardDismissedDay, forKey: cardDismissedDayKey)
    }

    // MARK: - Support flow

    /// Present the rewarded ad; on success, add one coffee.
    /// Returns `true` if a coffee was earned.
    func buyCoffee() async -> Bool {
        let earned = await RewardedAdManager.support.showAd()
        if earned {
            coffeeCount += 1
            defaults.set(coffeeCount, forKey: coffeeCountKey)
            // Having just supported, don't show the card again today.
            dismissCardForToday()
        }
        return earned
    }

    /// Warm the next support ad so the flow feels instant when invoked.
    func preload() {
        RewardedAdManager.support.preloadIfNeeded()
    }
}
