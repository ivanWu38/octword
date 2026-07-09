import FirebaseAnalytics

/// Centralized Firebase Analytics event logging
struct AnalyticsService {

    // MARK: - Game Lifecycle

    static func logGameStart(mode: GameMode, difficulty: Difficulty, isArchive: Bool = false) {
        Analytics.logEvent("game_start", parameters: [
            "mode": mode.rawValue,
            "difficulty": difficulty.rawValue,
            "board_count": difficulty.boardCount,
            "is_archive": isArchive
        ])
    }

    static func logGameComplete(gameState: GameState) {
        let boardsSolved = gameState.boards.filter { $0.isSolved }.count
        Analytics.logEvent("game_complete", parameters: [
            "mode": gameState.mode.rawValue,
            "difficulty": gameState.difficulty.rawValue,
            "is_won": gameState.isWon,
            "guess_count": gameState.guessCount,
            "elapsed_seconds": gameState.elapsedSeconds,
            "star_rating": gameState.starRating,
            "boards_solved": boardsSolved,
            "is_archive": gameState.isArchive
        ])
    }

    static func logGameAbandon(gameState: GameState) {
        let boardsSolved = gameState.boards.filter { $0.isSolved }.count
        Analytics.logEvent("game_abandon", parameters: [
            "mode": gameState.mode.rawValue,
            "difficulty": gameState.difficulty.rawValue,
            "guess_count": gameState.guessCount,
            "boards_solved": boardsSolved,
            "elapsed_seconds": gameState.elapsedSeconds,
            "is_archive": gameState.isArchive
        ])
    }

    // MARK: - Challenges

    static func logChallengeStart(presetId: String) {
        Analytics.logEvent("challenge_start", parameters: [
            "preset_id": presetId
        ])
    }

    static func logChallengeEnd(presetId: String, boardsSolved: Int, gamesCompleted: Int, isNewBest: Bool) {
        Analytics.logEvent("challenge_end", parameters: [
            "preset_id": presetId,
            "boards_solved": boardsSolved,
            "games_completed": gamesCompleted,
            "is_new_best": isNewBest
        ])
    }

    // MARK: - Pack Unlock Funnel

    static func logLockedPackView(categoryId: String) {
        Analytics.logEvent("locked_pack_view", parameters: [
            "category_id": categoryId
        ])
    }

    static func logUnlockPackAdTap(categoryId: String) {
        Analytics.logEvent("unlock_pack_ad_tap", parameters: [
            "category_id": categoryId
        ])
    }

    static func logUnlockPackPremiumTap(categoryId: String) {
        Analytics.logEvent("unlock_pack_premium_tap", parameters: [
            "category_id": categoryId
        ])
    }

    static func logRewardedAdEarned(placement: String) {
        Analytics.logEvent("rewarded_ad_earned", parameters: [
            "placement": placement
        ])
    }

    // MARK: - Onboarding

    static func logTutorialBegin() {
        Analytics.logEvent(AnalyticsEventTutorialBegin, parameters: nil)
    }

    static func logTutorialComplete(skipped: Bool) {
        Analytics.logEvent(AnalyticsEventTutorialComplete, parameters: [
            "skipped": skipped
        ])
    }

    // MARK: - Review Prompt

    static func logReviewPromptShown() {
        Analytics.logEvent("review_prompt_shown", parameters: nil)
    }

    static func logReviewPromptResponse(accepted: Bool) {
        Analytics.logEvent("review_prompt_response", parameters: [
            "accepted": accepted
        ])
    }

    // MARK: - Themes

    static func logThemeSelected(themeId: String) {
        Analytics.logEvent("theme_selected", parameters: [
            "theme_id": themeId
        ])
    }

    // MARK: - User Actions

    static func logShareResult(gameState: GameState) {
        Analytics.logEvent("share_result", parameters: [
            "mode": gameState.mode.rawValue,
            "difficulty": gameState.difficulty.rawValue,
            "is_won": gameState.isWon,
            "star_rating": gameState.starRating
        ])
    }

    static func logAchievementUnlocked(achievement: Achievement) {
        Analytics.logEvent("achievement_unlocked", parameters: [
            "achievement_id": achievement.rawValue
        ])
    }

    static func logInvalidWordAttempt(word: String, difficulty: Difficulty) {
        Analytics.logEvent("invalid_word_attempt", parameters: [
            "word": word.lowercased(),
            "difficulty": difficulty.rawValue
        ])
    }

    // MARK: - Subscription

    static func logPaywallView() {
        Analytics.logEvent("paywall_view", parameters: nil)
    }

    static func logPlanSelected(productId: String) {
        Analytics.logEvent("plan_selected", parameters: [
            "product_id": productId
        ])
    }

    static func logPurchaseTap(productId: String) {
        Analytics.logEvent("purchase_tap", parameters: [
            "product_id": productId
        ])
    }

    static func logPurchaseSuccess(productId: String) {
        Analytics.logEvent("purchase_success", parameters: [
            "product_id": productId
        ])
    }

    static func logPurchaseFail(productId: String, error: String) {
        Analytics.logEvent("purchase_fail", parameters: [
            "product_id": productId,
            "error": error
        ])
    }

    static func logRestoreTap() {
        Analytics.logEvent("restore_tap", parameters: nil)
    }
}
