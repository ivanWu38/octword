import SwiftUI

/// Post-game analysis screen. Pushed from the result screen via "Solve Report".
/// Replays the solve and shows efficiency, the sharpest guess, a guess-by-guess
/// breakdown of how the answer pool collapsed, and a per-board summary.
struct SolveReportView: View {
    let gameState: GameState
    let puzzleNumber: Int?

    @State private var report: SolveReport?

    var body: some View {
        ScrollView {
            if let report = report {
                VStack(spacing: 0) {
                    efficiencyHero(report)
                    sectionDivider
                    if let sharpest = sharpestGuess(report) {
                        sharpestSection(sharpest)
                        sectionDivider
                    }
                    breakdownSection(report)
                    sectionDivider
                    perBoardSection(report)
                }
                .padding(.bottom, 32)
                .iPadReadableWidth(520)
            }
        }
        .background(Color.quordleBackground.ignoresSafeArea())
        .navigationTitle("Solve Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if report == nil {
                report = SolveAnalyzer.analyze(gameState: gameState, pool: WordService.shared.solutionPool())
            }
        }
    }

    // MARK: - Efficiency Hero

    private func efficiencyHero(_ report: SolveReport) -> some View {
        VStack(spacing: 14) {
            if let number = puzzleNumber {
                Text("PUZZLE #\(number)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.quordleSecondaryText)
            }

            Text("EFFICIENCY")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundColor(.quordleSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(report.efficiency)")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundColor(.quordleCorrect)
                Text("/ 99")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
            }

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quordleCardBorder)
                    Capsule().fill(Color.quordleCorrect)
                        .frame(width: geo.size.width * CGFloat(report.efficiency) / 99.0)
                }
            }
            .frame(width: 220, height: 5)

            VStack(spacing: 4) {
                Text(report.verdict)
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

    // MARK: - Sharpest Guess

    private func sharpestGuess(_ report: SolveReport) -> GuessAnalysis? {
        guard let n = report.sharpestNumber else { return nil }
        return report.guesses.first { $0.number == n }
    }

    private func sharpestSection(_ guess: GuessAnalysis) -> some View {
        sectionContainer(title: "SHARPEST GUESS") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Guess \(guess.number) · \(guess.word)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Text("−\(guess.eliminated.formatted())")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.quordleCorrect)
                }

                wordTiles(guess.word)

                Text("Eliminated \(guess.eliminated.formatted()) possibilities across the boards in one move.")
                    .font(.system(size: 13))
                    .foregroundColor(.quordleSecondaryText)
            }
        }
    }

    private func wordTiles(_ word: String) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 42)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.quordleCorrect))
            }
        }
    }

    // MARK: - Guess Breakdown

    private func breakdownSection(_ report: SolveReport) -> some View {
        sectionContainer(title: "GUESS BREAKDOWN") {
            VStack(spacing: 0) {
                ForEach(Array(report.guesses.enumerated()), id: \.element.id) { idx, g in
                    breakdownRow(g)
                    if idx < report.guesses.count - 1 {
                        Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
                    }
                }
            }
        }
    }

    private func breakdownRow(_ g: GuessAnalysis) -> some View {
        VStack(spacing: 8) {
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

                Text("\(g.candidatesBefore.formatted()) → \(g.candidatesAfter.formatted())")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.quordleSecondaryText)

                tagChip(g.tag)
            }

            // Reduction bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.quordleCardBorder.opacity(0.5))
                    Capsule().fill(barColor(g.tag))
                        .frame(width: max(2, geo.size.width * CGFloat(g.reductionFraction)))
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func tagChip(_ tag: GuessTag) -> some View {
        switch tag {
        case .opener:
            chip(text: "Opener", color: .quordleGold, icon: "flag.fill")
        case .sharpest:
            chip(text: "Sharpest", color: .quordleCorrect, icon: "scissors")
        case .wasted:
            chip(text: "Soft", color: .quordleSecondaryText, icon: nil)
        case .none:
            EmptyView()
        }
    }

    private func chip(text: String, color: Color, icon: String?) -> some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon).font(.system(size: 8, weight: .bold))
            }
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
    }

    private func barColor(_ tag: GuessTag) -> Color {
        switch tag {
        case .sharpest: return .quordleCorrect
        case .opener: return .quordleGold
        case .wasted: return .quordleSecondaryText.opacity(0.5)
        case .none: return .quordleCorrect.opacity(0.65)
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

    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(.quordleSecondaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}
