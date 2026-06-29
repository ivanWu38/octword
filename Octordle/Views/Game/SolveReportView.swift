import SwiftUI

/// Post-game analysis screen. Shows two scores (Efficiency + Skill), the smartest
/// guess, a guess-by-guess quality breakdown, and a per-board summary.
struct SolveReportView: View {
    @ObservedObject var viewModel: GameViewModel
    let puzzleNumber: Int?

    var body: some View {
        ScrollView {
            if let report = viewModel.solveReport {
                VStack(spacing: 0) {
                    scoresHeader(report)
                    sectionDivider
                    if let smartest = smartestGuess(report) {
                        smartestSection(smartest)
                        sectionDivider
                    }
                    guessesSection(report)
                    sectionDivider
                    perBoardSection(report)
                }
                .padding(.bottom, 32)
                .iPadReadableWidth(520)
            } else {
                loadingView
            }
        }
        .background(Color.quordleBackground.ignoresSafeArea())
        .navigationTitle("Solve Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.ensureSolveReport() }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Analyzing your solve…")
                .font(.system(size: 14))
                .foregroundColor(.quordleSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    // MARK: - Scores Header

    private func scoresHeader(_ report: SolveReport) -> some View {
        VStack(spacing: 14) {
            if let number = puzzleNumber {
                Text("PUZZLE #\(number)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.quordleSecondaryText)
            }

            Text("SKILL")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundColor(.quordleSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(report.skill)")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundColor(.quordleCorrect)
                Text("/ 100")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quordleCardBorder)
                    Capsule().fill(Color.quordleCorrect)
                        .frame(width: geo.size.width * CGFloat(report.skill) / 100.0)
                }
            }
            .frame(width: 220, height: 5)

            VStack(spacing: 4) {
                Text(report.headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.quordlePrimaryText)
                Text(report.detail)
                    .font(.system(size: 14))
                    .foregroundColor(.quordleSecondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
    }

    // MARK: - Smartest Guess

    private func smartestGuess(_ report: SolveReport) -> GuessAnalysis? {
        guard let n = report.smartestNumber else { return nil }
        return report.guesses.first { $0.number == n }
    }

    private func smartestSection(_ guess: GuessAnalysis) -> some View {
        sectionContainer(title: "SMARTEST GUESS") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Guess \(guess.number) · \(guess.word)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    dots(guess.rating)
                }
                wordTiles(guess.word, color: ratingColor(guess.rating))
                Text(smartestBlurb(guess.rating))
                    .font(.system(size: 13))
                    .foregroundColor(.quordleSecondaryText)
            }
        }
    }

    private func smartestBlurb(_ rating: GuessRating) -> String {
        switch rating {
        case .brilliant: return "Near-perfect — almost no word would have revealed more."
        case .great: return "A strong, sharp choice that cut the field right down."
        default: return "Your most informative guess of the game."
        }
    }

    private func wordTiles(_ word: String, color: Color) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 42)
                    .background(RoundedRectangle(cornerRadius: 5).fill(color))
            }
        }
    }

    // MARK: - Guesses

    private func guessesSection(_ report: SolveReport) -> some View {
        sectionContainer(
            title: "YOUR GUESSES",
            subtitle: "How close each guess came to the best play available that turn. More dots = a sharper choice."
        ) {
            VStack(spacing: 0) {
                ForEach(Array(report.guesses.enumerated()), id: \.element.id) { idx, g in
                    guessRow(g)
                    if idx < report.guesses.count - 1 {
                        Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
                    }
                }
            }
        }
    }

    private func guessRow(_ g: GuessAnalysis) -> some View {
        HStack(spacing: 10) {
            Text("\(g.number)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 16, alignment: .trailing)

            Text(g.word)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(.quordlePrimaryText)

            Spacer()

            dots(g.rating)

            Text(g.rating.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ratingColor(g.rating))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 11)
    }

    private func dots(_ rating: GuessRating) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < rating.dots ? ratingColor(rating) : Color.quordleCardBorder)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func ratingColor(_ rating: GuessRating) -> Color {
        switch rating {
        case .brilliant, .great: return .quordleCorrect
        case .good: return .quordleGold
        case .fair, .soft: return .quordleOrange
        }
    }

    // MARK: - Per Board

    private func perBoardSection(_ report: SolveReport) -> some View {
        sectionContainer(title: "PER BOARD · SOLVED ON GUESS") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<report.totalBoards, id: \.self) { i in
                    let solvedAt = report.boardSolvedAt[i]
                    VStack(spacing: 2) {
                        Text("Board \(i + 1)")
                            .font(.system(size: 11))
                            .foregroundColor(.quordleSecondaryText)
                        if let g = solvedAt {
                            Text("\(g)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.quordlePrimaryText)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.quordleCardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.quordleCardBorder, lineWidth: 1))
                    )
                }
            }
        }
    }

    // MARK: - Shared chrome

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.quordleCardBorder)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    private func sectionContainer<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.quordleSecondaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.quordleSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

/// Shows a Solve Report for a finished game that has no live view model — e.g. the
/// daily "completed" screen, which loads a saved result from disk. Wraps it in a
/// view model held for this view's lifetime so the analysis is computed once.
struct StandaloneSolveReportView: View {
    @StateObject private var viewModel: GameViewModel
    let puzzleNumber: Int?

    init(gameState: GameState, puzzleNumber: Int?) {
        _viewModel = StateObject(wrappedValue: GameViewModel(resuming: gameState))
        self.puzzleNumber = puzzleNumber
    }

    var body: some View {
        SolveReportView(viewModel: viewModel, puzzleNumber: puzzleNumber)
    }
}

/// Post-game flow shown in the result sheet. The result card comes first (instant,
/// no computation); the Solve Report is reachable from a button on that card and
/// is computed lazily + cached, so opening/closing it never recomputes.
struct PostGameFlowView: View {
    @ObservedObject var viewModel: GameViewModel
    let puzzleNumber: Int?
    var onReviewBoard: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    var body: some View {
        GameResultView(
            gameState: viewModel.gameState,
            viewModel: viewModel,
            puzzleNumber: puzzleNumber,
            onReviewBoard: onReviewBoard,
            onDone: onDone
        )
    }
}
