import Foundation

/// Loads the themed word packs and tracks per-category puzzle completion.
/// Unlock rules: free categories are always playable; everything is playable for
/// premium users; a rewarded ad permanently unlocks a single puzzle, and the
/// first ad also permanently "enters" the pack so its level list opens directly.
@MainActor
final class CategoryService: ObservableObject {
    static let shared = CategoryService()

    @Published private(set) var categories: [WordCategory] = []
    @Published private(set) var completedByCategory: [String: Set<Int>] = [:]
    /// Rewarded-ad unlocks, keyed "categoryId#puzzleIndex". Persisted — an ad
    /// buys the level for good, even across app restarts.
    @Published private(set) var adUnlockedPuzzles: Set<String> = []
    /// Locked packs the player has entered via a rewarded ad — they can re-open
    /// the pack's level list without watching another ad (individual levels
    /// inside still cost their own ad). Persisted across restarts.
    @Published private(set) var enteredPacks: Set<String> = []

    private let kProgress = "octordle_categoryProgress"
    private let kAdUnlocked = "octordle_adUnlockedPuzzles"
    private let kEnteredPacks = "octordle_enteredPacks"
    private let defaults = UserDefaults.standard

    private init() {
        loadCategories()
        loadProgress()
        adUnlockedPuzzles = Set(defaults.stringArray(forKey: kAdUnlocked) ?? [])
        enteredPacks = Set(defaults.stringArray(forKey: kEnteredPacks) ?? [])
    }

    // MARK: - Loading

    private func loadCategories() {
        guard let url = Bundle.main.url(forResource: "categories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WordCategoryData.self, from: data) else {
            categories = []
            return
        }
        categories = decoded.categories
    }

    private func loadProgress() {
        guard let data = defaults.data(forKey: kProgress),
              let decoded = try? JSONDecoder().decode([String: Set<Int>].self, from: data) else {
            return
        }
        completedByCategory = decoded
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(completedByCategory) {
            defaults.set(data, forKey: kProgress)
        }
    }

    // MARK: - Unlocking

    func isUnlocked(_ category: WordCategory, isPremium: Bool) -> Bool {
        category.free || isPremium
    }

    func isPuzzlePlayable(_ category: WordCategory, puzzleIndex: Int, isPremium: Bool) -> Bool {
        isUnlocked(category, isPremium: isPremium)
            || adUnlockedPuzzles.contains(adKey(category.id, puzzleIndex))
    }

    /// Whether the player can open a pack's level list directly (no entry ad):
    /// free/premium packs, or a locked pack already entered via a rewarded ad.
    func canEnter(_ category: WordCategory, isPremium: Bool) -> Bool {
        isUnlocked(category, isPremium: isPremium) || enteredPacks.contains(category.id)
    }

    /// Permanently unlock a single puzzle after a rewarded ad.
    func grantAdUnlock(categoryId: String, puzzleIndex: Int) {
        adUnlockedPuzzles.insert(adKey(categoryId, puzzleIndex))
        defaults.set(Array(adUnlockedPuzzles), forKey: kAdUnlocked)
    }

    /// Mark a locked pack as entered (first rewarded ad) so it opens directly next
    /// time. Individual levels inside still require their own ad.
    func markPackEntered(categoryId: String) {
        guard !enteredPacks.contains(categoryId) else { return }
        enteredPacks.insert(categoryId)
        defaults.set(Array(enteredPacks), forKey: kEnteredPacks)
    }

    private func adKey(_ categoryId: String, _ index: Int) -> String {
        "\(categoryId)#\(index)"
    }

    // MARK: - Progress

    func isCompleted(categoryId: String, puzzleIndex: Int) -> Bool {
        completedByCategory[categoryId]?.contains(puzzleIndex) ?? false
    }

    func completedCount(categoryId: String) -> Int {
        completedByCategory[categoryId]?.count ?? 0
    }

    /// First puzzle the player hasn't solved yet (for "continue" entry points).
    func nextUnsolvedIndex(in category: WordCategory) -> Int {
        let done = completedByCategory[category.id] ?? []
        return (0..<category.puzzleCount).first { !done.contains($0) } ?? 0
    }

    func markCompleted(categoryId: String, puzzleIndex: Int) {
        var done = completedByCategory[categoryId] ?? []
        guard !done.contains(puzzleIndex) else { return }
        done.insert(puzzleIndex)
        completedByCategory[categoryId] = done
        saveProgress()
    }

    /// Total solved / total puzzles across all packs (for the Explore hub card).
    var overallProgress: (solved: Int, total: Int) {
        let total = categories.reduce(0) { $0 + $1.puzzleCount }
        let solved = categories.reduce(0) { $0 + completedCount(categoryId: $1.id) }
        return (solved, total)
    }
}
