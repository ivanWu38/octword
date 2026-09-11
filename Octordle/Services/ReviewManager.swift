import Foundation
import SwiftUI

@MainActor
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    // MARK: - Published

    @Published var isPromptShowing = false

    // MARK: - UserDefaults Keys

    private let kLastPromptDate = "octordle_lastPromptDate"
    private let kConsecutivePromptCount = "octordle_consecutivePromptCount"
    private let kRatedVersion = "octordle_ratedVersion"
    private let kLastRatedDate = "octordle_lastRatedDate"

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
    /// After OK (sent to the App Store), don't ask again for this long even if the
    /// app version changes — a rater per release is a nag.
    private let ratedCooldownDays = 120

    private init() {}

    // MARK: - Computed Helpers

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var lastRatedVersion: String? { defaults.string(forKey: kRatedVersion) }

    private var hasRatedCurrentVersion: Bool {
        lastRatedVersion == currentAppVersion
    }

    private var lastRatedDate: Date? {
        get { defaults.object(forKey: kLastRatedDate) as? Date }
        set { defaults.set(newValue, forKey: kLastRatedDate) }
    }

    private(set) var consecutivePromptCount: Int {
        get { defaults.integer(forKey: kConsecutivePromptCount) }
        set { defaults.set(newValue, forKey: kConsecutivePromptCount) }
    }

    private(set) var lastPromptDate: Date? {
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
        /// Won on the day a day-streak milestone (7 / 30 / 100) was crossed.
        /// Unlike the one-shot streak achievements, this also fires on rebuilt
        /// streaks; the cooldown below prevents spam.
        case streakMilestone
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

        tryPrompt()
    }

    /// Shows the soft prompt if every guard passes. Returns whether it was shown.
    @discardableResult
    func tryPrompt(now: Date = Date()) -> Bool {
        guard shouldPrompt() else { return false }
        // Stamp at show time, not on button tap — a swiped-away sheet still
        // counts as an ask, so the daily/14-day spacing can't be bypassed.
        lastPromptDate = now
        #if DEBUG
        print("[Review] shown at \(now)")
        #endif
        isPromptShowing = true
        AnalyticsService.logReviewPrompt("review_prompt_shown")
        return true
    }

    /// User tapped "OK". Marks this version rated; the presenting sheet then opens
    /// the App Store write-review page in `onDismiss` (`requestReview()` was
    /// dropped: 94 OK taps → 6 ratings, Apple's dialog mostly never showed).
    func userAccepted() {
        isPromptShowing = false
        defaults.set(currentAppVersion, forKey: kRatedVersion)
        lastRatedDate = Date()
        consecutivePromptCount = 0
        AnalyticsService.logReviewPrompt("review_prompt_accepted")
    }

    /// Deep link straight to the App Store's "Write a Review" form.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review")!
    }

    /// User tapped "Later" — increment the decline count.
    /// (`lastPromptDate` was already stamped when the prompt was shown.)
    func userDeclined() {
        #if DEBUG
        print("[Review] later at \(Date())")
        #endif
        isPromptShowing = false
        consecutivePromptCount += 1
        AnalyticsService.logReviewPrompt("review_prompt_later")
    }

    /// The sheet was closed without either button (swipe / tap outside / backgrounded).
    /// Counts exactly like Later so the player isn't asked again at the next game.
    func userDismissedWithoutChoice() {
        #if DEBUG
        print("[Review] dismissed without choice at \(Date())")
        #endif
        isPromptShowing = false
        consecutivePromptCount += 1
        AnalyticsService.logReviewPrompt("review_prompt_dismissed")
    }

    // MARK: - Dev util

    func resetAll() {
        for key in [kLastPromptDate, kConsecutivePromptCount, kRatedVersion, kLastRatedDate] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Gating

    private func shouldPrompt() -> Bool {
        // Don't prompt if already rated this version
        guard !hasRatedCurrentVersion else { return false }
        if let rated = lastRatedDate, daysSince(rated) < ratedCooldownDays { return false }

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
}
