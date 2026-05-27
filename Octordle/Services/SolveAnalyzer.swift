import Foundation

/// Tag describing the role a guess played in the solve.
enum GuessTag: Equatable {
    case none
    case opener
    case sharpest
    case wasted
}

/// Analysis of a single guess within a finished game.
struct GuessAnalysis: Identifiable {
    let id = UUID()
    let number: Int            // 1-based guess number
    let word: String
    let candidatesBefore: Int  // total possible answers across still-unsolved boards, before this guess
    let candidatesAfter: Int   // ...after this guess
    var tag: GuessTag

    /// How many possibilities this guess removed across all boards.
    var eliminated: Int { max(0, candidatesBefore - candidatesAfter) }

    /// Fraction of the pool removed (0...1).
    var reductionFraction: Double {
        guard candidatesBefore > 0 else { return 0 }
        return Double(eliminated) / Double(candidatesBefore)
    }
}

/// The complete post-game report.
struct SolveReport {
    let isWon: Bool
    let solvedCount: Int
    let totalBoards: Int
    let guessCount: Int
    let maxGuesses: Int
    let efficiency: Int            // 0...99
    let verdict: String            // headline sentence
    let detail: String             // supporting sentence
    let guesses: [GuessAnalysis]
    let sharpestNumber: Int?       // guess number with the largest elimination
    let boardSolvedAt: [Int?]      // per board: guess number solved, or nil
}

/// Builds a `SolveReport` from a finished game by replaying every guess against
/// the answer pool and measuring how the space of possible solutions collapsed.
///
/// Pure value type — no UI, no global state. Runs in well under a frame for an 8-board game.
enum SolveAnalyzer {

    /// Standard Wordle feedback, encoded as a base-3 integer (0 = absent, 1 = present, 2 = correct).
    /// Encoding the pattern as an Int makes candidate comparison a single `==`.
    private static func feedbackCode(guess: [Character], target: [Character]) -> Int {
        var result = [0, 0, 0, 0, 0]
        var counts: [Character: Int] = [:]
        for c in target { counts[c, default: 0] += 1 }

        // First pass: correct positions.
        for i in 0..<5 where guess[i] == target[i] {
            result[i] = 2
            counts[guess[i], default: 0] -= 1
        }
        // Second pass: present letters, respecting remaining counts.
        for i in 0..<5 where result[i] != 2 {
            let c = guess[i]
            if counts[c, default: 0] > 0 {
                result[i] = 1
                counts[c, default: 0] -= 1
            }
        }

        var code = 0
        for state in result { code = code * 3 + state }
        return code
    }

    static func analyze(gameState: GameState, pool: [String]) -> SolveReport {
        let boards = gameState.boards
        let boardCount = boards.count
        let targets = boards.map { Array($0.targetWord) }
        let solvedAt = boards.map { $0.solvedAtGuess }   // 1-based, or nil

        // Reconstruct the ordered guess words. The board solved last (or any unsolved
        // board on a loss) holds the full guess sequence, so take the longest history.
        let guessWords: [String] = (boards.max(by: { $0.guesses.count < $1.guesses.count })?.guesses ?? [])
            .map { row in row.map { $0.letter }.joined().uppercased() }

        // Per-board candidate sets, pre-converted to char arrays once.
        let poolChars = pool.map { Array($0.uppercased()) }
        var candidates: [[[Character]]] = Array(repeating: poolChars, count: boardCount)

        var analyses: [GuessAnalysis] = []

        for (idx, word) in guessWords.enumerated() {
            let number = idx + 1
            let guessChars = Array(word)

            // Count candidates across boards not yet solved going INTO this guess.
            var before = 0
            for b in 0..<boardCount where (solvedAt[b] == nil || solvedAt[b]! >= number) {
                before += candidates[b].count
            }

            // Filter each active board's candidate set by feedback consistency.
            for b in 0..<boardCount where (solvedAt[b] == nil || solvedAt[b]! >= number) {
                let actual = feedbackCode(guess: guessChars, target: targets[b])
                candidates[b] = candidates[b].filter { feedbackCode(guess: guessChars, target: $0) == actual }
            }

            // Count candidates across boards still unsolved AFTER this guess.
            var after = 0
            for b in 0..<boardCount where (solvedAt[b] == nil || solvedAt[b]! > number) {
                after += candidates[b].count
            }

            analyses.append(GuessAnalysis(
                number: number,
                word: word,
                candidatesBefore: before,
                candidatesAfter: after,
                tag: .none
            ))
        }

        // Tagging.
        if !analyses.isEmpty {
            analyses[0].tag = .opener
        }
        var sharpestNumber: Int? = nil
        if let maxA = analyses.max(by: { $0.eliminated < $1.eliminated }), maxA.eliminated > 0 {
            sharpestNumber = maxA.number
            if let i = analyses.firstIndex(where: { $0.number == maxA.number }) {
                analyses[i].tag = .sharpest
            }
        }
        // Flag clearly wasted guesses (removed < 4% of the field, not the opener / sharpest).
        for i in analyses.indices where analyses[i].tag == .none {
            if analyses[i].candidatesBefore > 30 && analyses[i].reductionFraction < 0.04 {
                analyses[i].tag = .wasted
            }
        }

        let solvedCount = boards.filter { $0.isSolved }.count
        let efficiency = computeEfficiency(
            isWon: gameState.isWon,
            solvedCount: solvedCount,
            boardCount: boardCount,
            guessCount: gameState.guessCount,
            maxGuesses: gameState.difficulty.maxGuesses,
            analyses: analyses
        )
        let (verdict, detail) = verdictText(
            efficiency: efficiency,
            isWon: gameState.isWon,
            solvedCount: solvedCount,
            boardCount: boardCount,
            guessCount: gameState.guessCount
        )

        return SolveReport(
            isWon: gameState.isWon,
            solvedCount: solvedCount,
            totalBoards: boardCount,
            guessCount: gameState.guessCount,
            maxGuesses: gameState.difficulty.maxGuesses,
            efficiency: efficiency,
            verdict: verdict,
            detail: detail,
            guesses: analyses,
            sharpestNumber: sharpestNumber,
            boardSolvedAt: solvedAt
        )
    }

    // MARK: - Scoring

    private static func computeEfficiency(
        isWon: Bool,
        solvedCount: Int,
        boardCount: Int,
        guessCount: Int,
        maxGuesses: Int,
        analyses: [GuessAnalysis]
    ) -> Int {
        // Economy: fewer guesses relative to the allowance is better.
        // Floor is boardCount (each guess solves at most one board).
        let floor = max(1, boardCount)
        let span = max(1, maxGuesses - floor)
        let economy = clamp(Double(maxGuesses - guessCount) / Double(span), 0, 1)

        // Opener: how much of the field the first guess removed.
        let opener = analyses.first?.reductionFraction ?? 0

        // Consistency: share of guesses that meaningfully cut the field (or solved a board).
        let meaningful = analyses.filter { $0.reductionFraction >= 0.10 }.count
        let consistency = analyses.isEmpty ? 0 : Double(meaningful) / Double(analyses.count)

        // Completion gates the whole score — an unsolved board caps the ceiling.
        let completion = Double(solvedCount) / Double(boardCount)

        let raw = 0.5 * economy + 0.3 * opener + 0.2 * consistency
        let gated = isWon ? raw : raw * (0.4 + 0.5 * completion)
        return Int((99 * clamp(gated, 0, 1)).rounded())
    }

    private static func verdictText(
        efficiency: Int,
        isWon: Bool,
        solvedCount: Int,
        boardCount: Int,
        guessCount: Int
    ) -> (String, String) {
        let detail: String = isWon
            ? "Solved all \(boardCount) in \(guessCount) guesses."
            : "Solved \(solvedCount) of \(boardCount) boards."

        let verdict: String
        if !isWon {
            verdict = solvedCount >= boardCount - 1 ? "So close — one board slipped away." : "A tough board today."
        } else {
            switch efficiency {
            case 85...: verdict = "Textbook solve. Ruthless efficiency."
            case 70..<85: verdict = "Sharp and steady throughout."
            case 55..<70: verdict = "Solid — a little room to tighten up."
            default: verdict = "You got there. A few guesses went to waste."
            }
        }
        return (verdict, detail)
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }
}
