import SwiftUI

/// Puzzle picker for one themed pack — numbered chips, solved ones checked off.
struct CategoryDetailView: View {
    let category: WordCategory

    @EnvironmentObject var themeService: ThemeService
    @ObservedObject private var categoryService = CategoryService.shared

    @State private var selectedIndex = 0
    @State private var showGame = false

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<category.puzzleCount, id: \.self) { index in
                        puzzleChip(index)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer().frame(height: 110)
            }
            .iPadReadableWidth(520)
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
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: category.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text("Word Pack")
                    .tracking(2)
                    .textCase(.uppercase)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.quordleSecondaryText)
            .padding(.bottom, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            Text(category.name)
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .padding(.vertical, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            Text("\(categoryService.completedCount(categoryId: category.id)) of \(category.puzzleCount) solved")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
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
