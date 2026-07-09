import Foundation

/// Loads the themed word packs and tracks per-category puzzle completion.
/// Unlock rules: free categories are always playable; everything is playable for
/// premium users; one paid category rotates in as "free today"; and a rewarded ad
/// can unlock a single puzzle for the current session.
@MainActor
final class CategoryService: ObservableObject {
    static let shared = CategoryService()

    @Published private(set) var categories: [WordCategory] = []
    @Published private(set) var completedByCategory: [String: Set<Int>] = [:]
    /// Session-only rewarded-ad unlocks, keyed "categoryId#puzzleIndex".
    @Published private(set) var adUnlockedPuzzles: Set<String> = []

    private let kProgress = "octordle_categoryProgress"
    private let defaults = UserDefaults.standard

    private init() {
        loadCategories()
        loadProgress()
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

    /// The paid category that is free to play today — rotates daily so there's
    /// always something new to come back for.
    var dailyFreeCategoryId: String? {
        let paid = categories.filter { !$0.free }
        guard !paid.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let daySeed = Int(formatter.string(from: Date())) ?? 0
        return paid[daySeed % paid.count].id
    }

    func isUnlocked(_ category: WordCategory, isPremium: Bool) -> Bool {
        category.free || isPremium || category.id == dailyFreeCategoryId
    }

    func isPuzzlePlayable(_ category: WordCategory, puzzleIndex: Int, isPremium: Bool) -> Bool {
        isUnlocked(category, isPremium: isPremium)
            || adUnlockedPuzzles.contains(adKey(category.id, puzzleIndex))
    }

    /// Grant a one-session unlock for a single puzzle after a rewarded ad.
    func grantAdUnlock(categoryId: String, puzzleIndex: Int) {
        adUnlockedPuzzles.insert(adKey(categoryId, puzzleIndex))
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
