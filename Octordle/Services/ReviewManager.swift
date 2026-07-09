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
    private let kSystemReviewRequestDates = "octordle_systemReviewRequestDates"

    private let defaults = UserDefaults.standard

    // MARK: - Tuning

    /// Never ask again the same day, and always leave this many days between any
    /// two prompts (accepted or declined) so the ask stays rare and welcome.
    private let kMinDaysBetweenPrompts = 14
    /// After this many "Later"s in a row, back off hard (see kDeclineCooldownDays)
    /// instead of chipping away at the same player every couple of weeks.
    private let kMaxConsecutiveDeclines = 2
    private let kDeclineCooldownDays = 90
    /// Apple silently no-ops the native dialog once it's been used ~3 times in a
    /// rolling year for this app. Track our own usage so we can fall back to the
    /// App Store's write-review page instead of asking into the void.
    private let kMaxSystemReviewRequestsPerYear = 3

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

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    // MARK: - Triggers

    /// The "happy moments" that are worth asking a player to review at. All of
    /// these fire only on positive beats — nothing on the player's very first
    /// game, and nothing tied to a loss.
    enum ReviewTrigger {
        /// Unlocked an achievement (any of them except `.firstWord`, which is
        /// too early in the journey to ask).
        case achievement
        /// Crossed a daily-challenges-completed milestone (5 / 15 / 40 / 80).
        case dailyMilestone
        /// Beat a personal best — most boards solved in one game, or fastest win.
        case personalBest
        /// Won with a 3-star rating. Repeatable; the cooldown below prevents spam.
        case perfectWin
    }

    /// Achievements excluded from the review-prompt trigger set.
    static let excludedAchievementTriggers: Set<Achievement> = [.firstWord]

    /// Call at game end with whichever triggers that game qualifies for (see
    /// `ReviewTrigger`). If any are present and the guards pass, arm the soft
    /// prompt — the game screen shows it after the achievement/theme cards.
    func considerPrompt(triggers: [ReviewTrigger]) {
        guard !triggers.isEmpty else { return }

        // Reset the decline cycle on a new app version so users can be asked again.
        if let stored = defaults.string(forKey: kRatedVersion),
           stored != currentAppVersion,
           stored != "" {
            consecutivePromptCount = 0
        }

        guard shouldPrompt() else { return }
        // Stamp at show time, not on button tap — a swiped-away sheet still
        // counts as an ask, so the daily/14-day spacing can't be bypassed.
        lastPromptDate = Date()
        showReviewPrompt = true
    }

    /// User tapped "OK". Uses Apple's native review sheet while we're within its
    /// yearly budget; otherwise sends the player straight to the write-review
    /// page so the ask isn't wasted on a dialog that won't show.
    func userAccepted() {
        showReviewPrompt = false
        defaults.set(currentAppVersion, forKey: kRatedVersion)
        consecutivePromptCount = 0

        let recentRequests = recentSystemReviewRequests()
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene

        if recentRequests.count < kMaxSystemReviewRequestsPerYear, let windowScene {
            systemReviewRequestDates = recentRequests + [Date()]
            AppStore.requestReview(in: windowScene)
        } else {
            openWriteReviewPage()
        }
    }

    /// User tapped "Later" — increment the decline count.
    /// (`lastPromptDate` was already stamped when the prompt was shown.)
    func userDeclined() {
        showReviewPrompt = false
        consecutivePromptCount += 1
    }

    // MARK: - Gating

    private func shouldPrompt() -> Bool {
        // Don't prompt if already rated this version
        guard !hasRatedCurrentVersion else { return false }

        // Don't prompt twice in the same day
        guard !wasPromptedToday else { return false }

        // Always leave breathing room since the last prompt of any kind. No
        // `lastPromptDate` means we've never prompted, which always passes.
        if let last = lastPromptDate {
            guard daysSince(last) >= kMinDaysBetweenPrompts else { return false }
        }

        // After a couple of declines in a row, back off hard until enough time
        // has passed, then give it another shot.
        if consecutivePromptCount >= kMaxConsecutiveDeclines {
            guard let last = lastPromptDate, daysSince(last) >= kDeclineCooldownDays else { return false }
            consecutivePromptCount = 0
        }

        return true
    }

    // MARK: - Write-review fallback bookkeeping

    private var systemReviewRequestDates: [Date] {
        get { (defaults.array(forKey: kSystemReviewRequestDates) as? [Date]) ?? [] }
        set { defaults.set(newValue, forKey: kSystemReviewRequestDates) }
    }

    /// Returns request dates from the past year, pruning anything older on read.
    private func recentSystemReviewRequests() -> [Date] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        let all = systemReviewRequestDates
        let recent = all.filter { $0 >= cutoff }
        if recent.count != all.count {
            systemReviewRequestDates = recent
        }
        return recent
    }

    private func openWriteReviewPage() {
        guard let url = URL(string: "https://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review") else { return }
        UIApplication.shared.open(url)
    }
}
