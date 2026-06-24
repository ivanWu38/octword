import Foundation

/// Service for managing daily puzzles
@MainActor
class DailyPuzzleService: ObservableObject {
    static let shared = DailyPuzzleService()

    private let defaults = UserDefaults.standard
    private let completedDatesKey = "octordle_completedDailyDates"
    private let unlockedDatesKey = Constants.UserDefaultsKeys.archiveUnlockedDates

    @Published private(set) var completedDates: Set<String> = []
    /// Archive days the player has unlocked by watching a rewarded ad.
    @Published private(set) var unlockedArchiveDates: Set<String> = []
    @Published private(set) var countdownString: String = "--:--:--"

    private var countdownTimer: Timer?

    /// Shared formatter for "yyyy-MM-dd" day strings.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        loadCompletedDates()
        loadUnlockedDates()
        updateCountdown()
        startCountdownTimer()
    }

    /// Check if today's puzzle is completed
    var isTodayCompleted: Bool {
        completedDates.contains(todayString)
    }

    /// Today's date string
    var todayString: String {
        Self.dateFormatter.string(from: Date())
    }

    /// Day string for an arbitrary date.
    func dateString(for date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    /// Get puzzle number (days since launch). Puzzle #1 is the launch day.
    var puzzleNumber: Int {
        puzzleNumber(for: Date())
    }

    /// Puzzle number for an arbitrary date (Puzzle #1 == firstPuzzleDate).
    func puzzleNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: firstPuzzleDate, to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    // MARK: - Archive

    /// The earliest playable day (Puzzle #1), start of day.
    var firstPuzzleDate: Date {
        let calendar = Calendar.current
        let date = calendar.date(from: Constants.Archive.firstPuzzleComponents) ?? Date()
        return calendar.startOfDay(for: date)
    }

    /// Today, normalized to start of day.
    var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Whether a date is within the playable archive range [firstPuzzleDate ... today].
    func isInArchiveRange(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return day >= firstPuzzleDate && day <= todayStart
    }

    /// Whether a date falls inside the free window (today + previous freeDays-1 days).
    func isFree(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let diff = Calendar.current.dateComponents([.day], from: day, to: todayStart).day ?? Int.max
        return diff >= 0 && diff < Constants.Archive.freeDays
    }

    /// Whether the puzzle for a date has been completed.
    func isCompleted(_ date: Date) -> Bool {
        completedDates.contains(dateString(for: date))
    }

    /// Whether an archive day was unlocked via rewarded ad.
    func isAdUnlocked(_ date: Date) -> Bool {
        unlockedArchiveDates.contains(dateString(for: date))
    }

    /// Whether the player can start/resume the puzzle for a date.
    func isPlayable(_ date: Date, isPremium: Bool) -> Bool {
        guard isInArchiveRange(date) else { return false }
        return isFree(date) || isPremium || isAdUnlocked(date)
    }

    /// Whether a date needs unlocking (in range, not free, not premium, not yet unlocked).
    func isLocked(_ date: Date, isPremium: Bool) -> Bool {
        guard isInArchiveRange(date) else { return false }
        return !isFree(date) && !isPremium && !isAdUnlocked(date)
    }

    /// Unlock an archive day after a rewarded ad was watched.
    func unlockArchiveDate(_ date: Date) {
        unlockedArchiveDates.insert(dateString(for: date))
        saveUnlockedDates()
    }

    /// Time until next puzzle (next local midnight)
    var timeUntilNextPuzzle: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return 0
        }
        return midnight.timeIntervalSince(now)
    }

    /// Start the countdown timer
    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdown()
            }
        }
    }

    /// Update the countdown string
    private func updateCountdown() {
        let interval = timeUntilNextPuzzle
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        countdownString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Mark today as completed
    func markTodayCompleted() {
        markCompleted(todayString)
    }

    /// Mark an arbitrary day's puzzle as completed (used by archive).
    func markCompleted(_ dayString: String) {
        completedDates.insert(dayString)
        saveCompletedDates()
    }

    /// Get current streak.
    /// The streak earned up to yesterday stays alive until today's day ends, so we don't
    /// show 0 in the morning before the user has played today's puzzle. If today isn't
    /// completed yet, we start counting from yesterday instead of today.
    var currentStreak: Int {
        var streak = 0
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var date = Date()
        if !completedDates.contains(formatter.string(from: date)) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else {
                return 0
            }
            date = yesterday
        }

        while completedDates.contains(formatter.string(from: date)) {
            streak += 1
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }

        return streak
    }

    /// The streak value that *will* hold once today's daily is recorded. Used at
    /// game end to evaluate streak rewards (achievements / themes) on the correct
    /// day, since `markTodayCompleted()` runs later (when the result sheet closes).
    var streakIncludingToday: Int {
        if isTodayCompleted { return currentStreak }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var streak = 1 // today, about to be completed
        var date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        while completedDates.contains(formatter.string(from: date)) {
            streak += 1
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        return streak
    }

    #if DEBUG
    /// TEMPORARY QA: pretend the player completed the `count` days immediately
    /// before today, so finishing today's daily crosses a streak threshold.
    func debugSeedConsecutiveDaysBeforeToday(_ count: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for offset in 1...max(1, count) {
            if let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                completedDates.insert(formatter.string(from: day))
            }
        }
        saveCompletedDates()
    }
    #endif

    // MARK: - Persistence

    private func loadCompletedDates() {
        if let dates = defaults.stringArray(forKey: completedDatesKey) {
            self.completedDates = Set(dates)
        }
    }

    private func saveCompletedDates() {
        defaults.set(Array(completedDates), forKey: completedDatesKey)
    }

    private func loadUnlockedDates() {
        if let dates = defaults.stringArray(forKey: unlockedDatesKey) {
            self.unlockedArchiveDates = Set(dates)
        }
    }

    private func saveUnlockedDates() {
        defaults.set(Array(unlockedArchiveDates), forKey: unlockedDatesKey)
    }
}
