import Foundation

/// Service for managing daily puzzles
@MainActor
class DailyPuzzleService: ObservableObject {
    static let shared = DailyPuzzleService()

    private let defaults = UserDefaults.standard
    private let completedDatesKey = "octordle_completedDailyDates"

    @Published private(set) var completedDates: Set<String> = []
    @Published private(set) var countdownString: String = "--:--:--"

    private var countdownTimer: Timer?

    private init() {
        loadCompletedDates()
        updateCountdown()
        startCountdownTimer()
    }

    /// Check if today's puzzle is completed
    var isTodayCompleted: Bool {
        completedDates.contains(todayString)
    }

    /// Today's date string
    var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Get puzzle number (days since launch). Puzzle #1 is the launch day.
    var puzzleNumber: Int {
        let calendar = Calendar.current
        let launchDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        let days = calendar.dateComponents([.day], from: launchDate, to: Date()).day ?? 0
        return max(1, days + 1)
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
        completedDates.insert(todayString)
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

    // MARK: - Persistence

    private func loadCompletedDates() {
        if let dates = defaults.stringArray(forKey: completedDatesKey) {
            self.completedDates = Set(dates)
        }
    }

    private func saveCompletedDates() {
        defaults.set(Array(completedDates), forKey: completedDatesKey)
    }
}
