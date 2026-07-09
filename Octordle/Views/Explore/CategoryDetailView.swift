import SwiftUI

/// Puzzle picker for one themed pack — numbered chips, solved ones checked off.
struct CategoryDetailView: View {
    let category: WordCategory

    @EnvironmentObject var themeService: ThemeService
    @ObservedObject private var categoryService = CategoryService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIndex = 0
    @State private var showGame = false

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
                .iPadReadableWidth(520)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<category.puzzleCount, id: \.self) { index in
                        puzzleChip(index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 110)
                .iPadReadableWidth(520)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showGame) {
            GameView(category: category, puzzleIndex: selectedIndex)
        }
    }

    // MARK: - Header

    private var header: some View {
        EditorialMasthead(
            kicker: "Word Pack",
            title: category.name,
            subtitle: "\(categoryService.completedCount(categoryId: category.id)) of \(category.puzzleCount) solved",
            onBack: { dismiss() }
        )
    }

    // MARK: - Chips

    private func puzzleChip(_ index: Int) -> some View {
        let solved = categoryService.isCompleted(categoryId: category.id, puzzleIndex: index)

        return Button {
            HapticManager.shared.buttonTap()
            selectedIndex = index
            showGame = true
        } label: {
            VStack(spacing: 5) {
                Text("\(index + 1)")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(solved ? .quordleCorrect : .quordlePrimaryText)

                Image(systemName: solved ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(solved ? .quordleCorrect : .quordleSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(solved ? Color.quordleCorrect.opacity(0.55) : Color.quordleCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: WordCategory(
            id: "animals", name: "Animals", symbol: "pawprint", free: true,
            puzzles: [["HORSE", "ZEBRA", "TIGER", "SNAKE", "MOUSE", "SHEEP", "CAMEL", "OTTER"]]
        ))
        .environmentObject(ThemeService.shared)
    }
}
