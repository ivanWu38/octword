import Foundation

/// Service for managing daily puzzles
@MainActor
class DailyPuzzleService: ObservableObject {
    static let shared = DailyPuzzleService()

    private let defaults = UserDefaults.standard
    private let completedDatesKey = "octordle_completedDailyDates"
    private let unlockedDatesKey = Constants.UserDefaultsKeys.archiveUnlockedDates
    private let streakDatesKey = Constants.UserDefaultsKeys.streakDates
    private let rescuedDatesKey = Constants.UserDefaultsKeys.rescuedStreakDates
    private let lastRescueDayKey = Constants.UserDefaultsKeys.lastStreakRescueDay
    private let rescueCardDismissedDayKey = Constants.UserDefaultsKeys.streakRescueCardDismissedDay
    private let streakMigratedKey = Constants.UserDefaultsKeys.streakDatesMigrated
    private let liveSolvedDatesKey = Constants.UserDefaultsKeys.liveSolvedDates
    private let streakRepairedKey = Constants.UserDefaultsKeys.streakDatesRepaired

    /// Every day whose puzzle has been finished (today or via the archive). Drives the
    /// calendar's "done" state and the Next-edition card; NOT the streak.
    @Published private(set) var completedDates: Set<String> = []
    /// Days whose puzzle was finished ON that day. Only these (plus rescued days)
    /// count toward the streak — catching up in the archive no longer repairs it.
    @Published private(set) var streakDates: Set<String> = []
    /// Days restored by the streak-rescue rewarded ad (or Premium).
    @Published private(set) var rescuedDates: Set<String> = []
    /// Days solved as today's puzzle, recorded the moment the game ends (see `recordLiveSolve`).
    /// Not part of the streak itself: it only proves that `markCompleted` for that day
    /// should count, and lets launch reconcile a solve whose result sheet was never closed.
    private(set) var liveSolvedDates: Set<String> = []
    /// Day string of the most recent rescue, for the cooldown.
    @Published private(set) var lastRescueDay: String?
    /// Day the player dismissed the "streak at risk" notice ("yyyy-MM-dd").
    @Published private(set) var rescueCardDismissedDay: String = ""
    /// Archive days the player has unlocked by watching a rewarded ad.
    @Published private(set) var unlockedArchiveDates: Set<String> = []

    /// Shared formatter for "yyyy-MM-dd" day strings.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        loadCompletedDates()
        loadUnlockedDates()
        loadStreakState()
        migrateStreakDatesIfNeeded()
        repairStreakDatesIfNeeded()
        reconcileLiveSolves()
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

    /// Whether a date is within the playable archive range [firstPuzzleDate ... yesterday].
    /// Today is excluded — it's the live daily, played on the Daily tab.
    func isInArchiveRange(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return day >= firstPuzzleDate && day < todayStart
    }

    /// Whether a date falls inside the free window — the most recent `freeDays` archive
    /// days (i.e. yesterday and back, excluding today).
    func isFree(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let diff = Calendar.current.dateComponents([.day], from: day, to: todayStart).day ?? Int.max
        return diff >= 1 && diff <= Constants.Archive.freeDays
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

    /// Mark today as completed
    func markTodayCompleted() {
        markCompleted(todayString)
    }

    /// Mark an arbitrary day's puzzle as completed (used by archive).
    /// Only a same-day completion counts toward the streak — "same-day" meaning the game
    /// was solved as today's puzzle (`recordLiveSolve`), regardless of when this is called.
    func markCompleted(_ dayString: String) {
        completedDates.insert(dayString)
        saveCompletedDates()
        if dayString == todayString || liveSolvedDates.contains(dayString) {
            streakDates.insert(dayString)
            saveStreakState()
            streakCache = nil
            // The streak just moved, which can unlock a theme.
            ThemeService.shared.invalidateResolvedTheme()
        }
    }

    /// Call the moment today's puzzle ends. Persists immediately so the day still counts
    /// toward the streak if the result sheet is closed after midnight, or never closed
    /// because the app was killed on it (reconciled on next launch).
    func recordLiveSolve(_ dayString: String) {
        guard !liveSolvedDates.contains(dayString) else { return }
        liveSolvedDates.insert(dayString)
        saveLiveSolvedDates()
    }

    /// Launch safety net: a live solve whose sheet was never dismissed (app killed) has a
    /// saved result but was never marked completed. Mark it now so the day isn't lost.
    func reconcileLiveSolves() {
        let missing = liveSolvedDates.filter { !completedDates.contains($0) || !streakDates.contains($0) }
        guard !missing.isEmpty else { return }
        completedDates.formUnion(missing)
        streakDates.formUnion(missing)
        saveCompletedDates()
        saveStreakState()
        streakCache = nil
    }

    // MARK: - Streak

    /// Whether a day keeps the streak alive: played on the day itself, or rescued.
    func countsTowardStreak(_ dayString: String) -> Bool {
        streakDates.contains(dayString) || rescuedDates.contains(dayString)
    }

    /// Day string `offset` days from today (negative = past).
    func dayString(offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return dateString(for: date)
    }

    /// Number of consecutive streak days ending on `dayString` (inclusive).
    /// A rescued day bridges the gap but is not itself a played day, so it keeps the
    /// run alive without adding to the count (a 12-day streak stays 12 after a rescue;
    /// today's play makes it 13, matching the "today counts as day N+1" copy).
    private func consecutiveStreakDays(endingOn dayString: String) -> Int {
        var streak = 0
        guard var date = Self.dateFormatter.date(from: dayString) else { return 0 }
        while countsTowardStreak(dateString(for: date)) {
            if streakDates.contains(dateString(for: date)) { streak += 1 }
            guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        return streak
    }

    // MARK: - Streak rescue

    /// The streak that ended yesterday, if the player missed exactly yesterday and the
    /// run before it was long enough to be worth restoring. `nil` otherwise.
    /// Window is today only: tomorrow the gap is two days and the streak is gone.
    var rescuableStreak: Int? {
        let yesterday = dayString(offset: -1)
        let dayBefore = dayString(offset: -2)
        guard !countsTowardStreak(yesterday), countsTowardStreak(dayBefore) else { return nil }
        let broken = consecutiveStreakDays(endingOn: dayBefore)
        return broken >= Constants.StreakRescue.minStreak ? broken : nil
    }

    /// One rescue per rolling cooldown window.
    var isRescueOnCooldown: Bool {
        guard let last = lastRescueDay, let lastDate = Self.dateFormatter.date(from: last) else { return false }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: todayStart).day ?? Int.max
        return days < Constants.StreakRescue.cooldownDays
    }

    /// Whether a rescue can be offered right now (rescuable gap + off cooldown).
    var canRescueStreak: Bool {
        rescuableStreak != nil && !isRescueOnCooldown
    }

    /// Whether the "streak at risk" notice should show on the Today tab.
    var shouldShowRescueCard: Bool {
        canRescueStreak && rescueCardDismissedDay != todayString
    }

    /// Restore yesterday so the streak continues. Call only after the rewarded ad was
    /// earned (or for Premium). Returns the streak as it stands after the rescue.
    @discardableResult
    func rescueStreak() -> Int {
        rescuedDates.insert(dayString(offset: -1))
        lastRescueDay = todayString
        rescueCardDismissedDay = todayString
        saveStreakState()
        streakCache = nil
        ThemeService.shared.invalidateResolvedTheme()
        objectWillChange.send()
        return currentStreak
    }

    /// Hide the "streak at risk" notice for the rest of today.
    func dismissRescueCardForToday() {
        rescueCardDismissedDay = todayString
        defaults.set(rescueCardDismissedDay, forKey: rescueCardDismissedDayKey)
    }

    // MARK: - Next edition (most recent unfinished past day)

    /// The most recent past day (within `lookback` days) whose puzzle isn't finished.
    func nextUnfinishedPastDate(lookback: Int = 30) -> Date? {
        for offset in 1...lookback {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            guard isInArchiveRange(date) else { return nil }
            if !isCompleted(date) { return date }
        }
        return nil
    }

    /// Get current streak.
    /// The streak earned up to yesterday stays alive until today's day ends, so we don't
    /// show 0 in the morning before the user has played today's puzzle. If today isn't
    /// completed yet, we start counting from yesterday instead of today.
    /// Cached streak, keyed by the day it was computed for so it expires by itself
    /// when the app is left open past midnight. Cleared whenever `completedDates`
    /// changes. Worth caching: this walks back day by day allocating `Date`s, and
    /// it sits behind `StatsService.maxStreak`, which theme resolution reads on
    /// every tile render.
    private var streakCache: (day: String, value: Int)?

    var currentStreak: Int {
        let today = todayString
        if let cache = streakCache, cache.day == today { return cache.value }
        let value = computeCurrentStreak()
        streakCache = (today, value)
        return value
    }

    private func computeCurrentStreak() -> Int {
        let start = countsTowardStreak(todayString) ? todayString : dayString(offset: -1)
        return consecutiveStreakDays(endingOn: start)
    }

    /// The streak value that *will* hold once today's daily is recorded. Used at
    /// game end to evaluate streak rewards (achievements / themes) on the correct
    /// day, since `markTodayCompleted()` runs later (when the result sheet closes).
    var streakIncludingToday: Int {
        if countsTowardStreak(todayString) { return currentStreak }
        return 1 + consecutiveStreakDays(endingOn: dayString(offset: -1))
    }

    #if DEBUG
    /// TEMPORARY QA: pretend the player completed the `count` days immediately
    /// before today, so finishing today's daily crosses a streak threshold.
    /// PreviewSeed: clear all daily history (in memory + on disk).
    func debugResetAll() {
        completedDates = []; streakDates = []; rescuedDates = []; unlockedArchiveDates = []
        lastRescueDay = nil; rescueCardDismissedDay = ""
        streakCache = nil
        saveCompletedDates(); saveUnlockedDates(); saveStreakState()
        defaults.set(true, forKey: streakMigratedKey)
    }

    func debugSeedConsecutiveDaysBeforeToday(_ count: Int) {
        for offset in 1...max(1, count) {
            let day = dayString(offset: -offset)
            completedDates.insert(day)
            streakDates.insert(day)
        }
        streakCache = nil
        saveCompletedDates()
        saveStreakState()
    }

    /// Harness: seed streak history for simulator testing.
    /// - gap1: 12-day streak ending the day before yesterday, yesterday missed (rescuable)
    /// - gap2: same but two days missed (not rescuable)
    /// - short: 2-day run before yesterday (below minStreak)
    /// - cooldown: gap1 plus a rescue used 2 days ago
    /// - done: gap1 and today already completed
    /// - nextup / nextupfree: today done, first unfinished archive day locked (-4) / free (-2)
    /// - latedismiss: yesterday solved live, sheet closed today → 13, no rescue
    /// - killed: app died on the sheet (never marked) → launch reconcile → 13
    /// - repair: 1.12 (2) damage, saved result ended yesterday → one-time repair → 13
    /// - repairarchive: negative control, saved result ended today → stays 12, rescuable
    func debugSeedStreak(_ scenario: String) {
        completedDates = []; streakDates = []; rescuedDates = []; unlockedArchiveDates = []; liveSolvedDates = []
        lastRescueDay = nil; rescueCardDismissedDay = ""
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.dailyResultPrefix + dayString(offset: -1))
        var runStart = -2, runLength = 12
        switch scenario {
        case "gap2": runStart = -3
        case "short": runLength = 2
        default: break
        }
        for i in 0..<runLength {
            let day = dayString(offset: runStart - i)
            completedDates.insert(day); streakDates.insert(day)
        }
        if scenario == "cooldown" { lastRescueDay = dayString(offset: -2) }
        if scenario == "done" { let t = todayString; completedDates.insert(t); streakDates.insert(t) }
        if scenario == "nextup" || scenario == "nextupfree" {
            completedDates = []; streakDates = []
            let doneOffsets = scenario == "nextup" ? [0, -1, -2, -3] : [0, -1]
            for o in doneOffsets { let d = dayString(offset: o); completedDates.insert(d); streakDates.insert(d) }
        }
        let yesterday = dayString(offset: -1)
        switch scenario {
        case "latedismiss":
            liveSolvedDates.insert(yesterday); saveLiveSolvedDates()
            markCompleted(yesterday)                      // the sheet closes today
        case "killed":
            liveSolvedDates.insert(yesterday); saveLiveSolvedDates()
            reconcileLiveSolves()                         // what init does on next launch
        case "repair", "repairarchive":
            completedDates.insert(yesterday)              // 1.12 (2) left it out of streakDates
            let yDate = Calendar.current.date(byAdding: .day, value: -1, to: todayStart)!
            var result = GameState(mode: .daily, difficulty: .classic, words: Array(repeating: "APPLE", count: 8), date: yDate)
            result.isGameOver = true; result.isWon = true
            result.endTime = scenario == "repair" ? yDate.addingTimeInterval(20 * 3600) : Date()
            defaults.set(try! JSONEncoder().encode(result), forKey: Constants.UserDefaultsKeys.dailyResultPrefix + yesterday)
            defaults.set(false, forKey: streakRepairedKey)
            repairStreakDatesIfNeeded()
        default: break
        }
        streakCache = nil
        saveCompletedDates(); saveUnlockedDates(); saveStreakState()
        defaults.set(true, forKey: streakMigratedKey)
        print("[StreakTest] completed(-1)=\(completedDates.contains(yesterday)) streakDates(-1)=\(streakDates.contains(yesterday)) live(-1)=\(liveSolvedDates.contains(yesterday))")
        print("[StreakTest] seeded \(scenario): streak=\(currentStreak) rescuable=\(String(describing: rescuableStreak)) cooldown=\(isRescueOnCooldown) canRescue=\(canRescueStreak) nextUp=\(String(describing: nextUnfinishedPastDate()))")
    }
    #endif

    // MARK: - Persistence

    private func loadCompletedDates() {
        if let dates = defaults.stringArray(forKey: completedDatesKey) {
            self.completedDates = Set(dates)
            streakCache = nil
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

    private func loadStreakState() {
        liveSolvedDates = Set(defaults.stringArray(forKey: liveSolvedDatesKey) ?? [])
        streakDates = Set(defaults.stringArray(forKey: streakDatesKey) ?? [])
        rescuedDates = Set(defaults.stringArray(forKey: rescuedDatesKey) ?? [])
        lastRescueDay = defaults.string(forKey: lastRescueDayKey)
        rescueCardDismissedDay = defaults.string(forKey: rescueCardDismissedDayKey) ?? ""
        streakCache = nil
    }

    private func saveLiveSolvedDates() {
        defaults.set(Array(liveSolvedDates), forKey: liveSolvedDatesKey)
    }

    private func saveStreakState() {
        defaults.set(Array(streakDates), forKey: streakDatesKey)
        defaults.set(Array(rescuedDates), forKey: rescuedDatesKey)
        defaults.set(lastRescueDay, forKey: lastRescueDayKey)
        defaults.set(rescueCardDismissedDay, forKey: rescueCardDismissedDayKey)
    }

    /// One-time migration: before streakDates existed, every completed day counted.
    /// Grandfather all of them so nobody's streak drops on update.
    private func migrateStreakDatesIfNeeded() {
        guard !defaults.bool(forKey: streakMigratedKey) else { return }
        streakDates.formUnion(completedDates)
        saveStreakState()
        defaults.set(true, forKey: streakMigratedKey)
        streakCache = nil
    }

    /// One-time repair for 1.12 (2): `markCompleted` ran when the result sheet closed, and
    /// only counted the day toward the streak if the sheet closed on the same calendar day.
    /// A player who solved the puzzle and closed the sheet the next morning has the day in
    /// `completedDates` but not `streakDates`. The saved result's `endTime` tells the two
    /// cases apart (an archive replay of that day would have ended on a later day).
    func repairStreakDatesIfNeeded() {
        guard !defaults.bool(forKey: streakRepairedKey) else { return }
        defaults.set(true, forKey: streakRepairedKey)
        let candidates = completedDates.subtracting(streakDates).subtracting(rescuedDates)
        var repaired: Set<String> = []
        for day in candidates {
            guard let data = defaults.data(forKey: Constants.UserDefaultsKeys.dailyResultPrefix + day),
                  let state = try? JSONDecoder().decode(GameState.self, from: data),
                  let endTime = state.endTime,
                  dateString(for: endTime) == day else { continue }
            repaired.insert(day)
        }
        guard !repaired.isEmpty else { return }
        streakDates.formUnion(repaired)
        saveStreakState()
        streakCache = nil
    }
}

/// The "Next Edition In" clock.
///
/// Deliberately a separate object from `DailyPuzzleService`: it publishes a new
/// value every second, and everything observing the puzzle service (Today, Journey,
/// Archive — all alive at once inside the TabView) would otherwise rebuild its whole
/// body on every tick. Only `CountdownText` observes this, so only that label redraws.
@MainActor
final class EditionCountdown: ObservableObject {
    static let shared = EditionCountdown()

    @Published private(set) var text: String = "--:--:--"

    private var timer: Timer?

    private init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    private func update() {
        let interval = DailyPuzzleService.shared.timeUntilNextPuzzle
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
