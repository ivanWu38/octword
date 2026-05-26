import FirebaseAnalytics

/// Centralized Firebase Analytics event logging
struct AnalyticsService {

    // MARK: - Game Lifecycle

    static func logGameStart(mode: GameMode, difficulty: Difficulty) {
        Analytics.logEvent("game_start", parameters: [
            "mode": mode.rawValue,
            "difficulty": difficulty.rawValue,
            "board_count": difficulty.boardCount
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
            "boards_solved": boardsSolved
        ])
    }

    static func logGameAbandon(gameState: GameState) {
        let boardsSolved = gameState.boards.filter { $0.isSolved }.count
        Analytics.logEvent("game_abandon", parameters: [
            "mode": gameState.mode.rawValue,
            "difficulty": gameState.difficulty.rawValue,
            "guess_count": gameState.guessCount,
            "boards_solved": boardsSolved,
            "elapsed_seconds": gameState.elapsedSeconds
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
