import Foundation
import StoreKit
import SwiftUI

@MainActor
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    // MARK: - Published

    @Published var showReviewPrompt = false

    // MARK: - UserDefaults Keys

    private let kLastPromptDate = "octordle_lastPromptDate"
    private let kConsecutivePromptCount = "octordle_consecutivePromptCount"
    private let kRatedVersion = "octordle_ratedVersion"

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Computed Helpers

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private var hasRatedCurrentVersion: Bool {
        defaults.string(forKey: kRatedVersion) == currentAppVersion
    }


    private var consecutivePromptCount: Int {
        get { defaults.integer(forKey: kConsecutivePromptCount) }
        set { defaults.set(newValue, forKey: kConsecutivePromptCount) }
    }

    private var lastPromptDate: Date? {
        get { defaults.object(forKey: kLastPromptDate) as? Date }
        set { defaults.set(newValue, forKey: kLastPromptDate) }
    }

    private var wasPromptedToday: Bool {
        guard let last = lastPromptDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Public API

    /// Achievements whose first unlock is a good "peak happiness" moment to ask
    /// for a review: a returning player (3-day streak), a strong single round
    /// (6+ boards), or sustained progress (25 words). All are positive moments
    /// and none fire on the player's very first game.
    private static let triggerAchievements: Set<Achievement> = [.streak3, .sharpEye, .wordCollector]

    /// Call at game end with the achievements newly unlocked by that game.
    /// If one of them is a review-worthy milestone (and the guards pass), arm the
    /// soft prompt — the game screen shows it after the achievement/theme cards.
    func considerPrompt(forNewlyUnlocked achievements: [Achievement]) {
        guard achievements.contains(where: { Self.triggerAchievements.contains($0) }) else { return }

        // Reset the decline cycle on a new app version so users can be asked again.
        if let stored = defaults.string(forKey: kRatedVersion),
           stored != currentAppVersion,
           stored != "" {
            consecutivePromptCount = 0
        }

        guard shouldPrompt() else { return }
        showReviewPrompt = true
    }

    /// User tapped "OK" — trigger native review & mark rated.
    func userAccepted() {
        showReviewPrompt = false
        defaults.set(currentAppVersion, forKey: kRatedVersion)
        consecutivePromptCount = 0

        // Trigger Apple's native review prompt
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    /// User tapped "Later" — increment prompt count.
    func userDeclined() {
        showReviewPrompt = false
        consecutivePromptCount += 1
        lastPromptDate = Date()
    }

    // MARK: - Trigger Logic

    private func shouldPrompt() -> Bool {
        // Don't prompt if already rated this version
        guard !hasRatedCurrentVersion else { return false }

        // Don't prompt twice in the same day
        guard !wasPromptedToday else { return false }

        // If prompted fewer than 7 times, allow
        if consecutivePromptCount < 7 {
            return true
        }

        // After 7 consecutive declines, wait 30 days before trying again
        if let last = lastPromptDate {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            if daysSince >= 30 {
                consecutivePromptCount = 0 // reset cycle
                return true
            }
        }

        return false
    }
}
