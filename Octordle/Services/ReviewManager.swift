import Foundation
import StoreKit
import SwiftUI

@MainActor
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    // MARK: - Published

    @Published var showReviewPrompt = false

    // MARK: - UserDefaults Keys

    private let kTotalLevelsFinished = "octordle_totalLevelsFinished"
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

    private var totalLevelsFinished: Int {
        get { defaults.integer(forKey: kTotalLevelsFinished) }
        set { defaults.set(newValue, forKey: kTotalLevelsFinished) }
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

    /// Call when the player wins a game.
    func recordLevelFinished() {
        // Reset counts on new app version
        if let stored = defaults.string(forKey: kRatedVersion),
           stored != currentAppVersion,
           stored != "" {
            // New version — reset so the user can be prompted again
            consecutivePromptCount = 0
        }

        totalLevelsFinished += 1

        guard shouldPrompt() else { return }

        // Small delay so the result sheet can appear first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showReviewPrompt = true
        }
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
        // Must have finished at least 3 levels total
        guard totalLevelsFinished >= 2 else { return false }

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
