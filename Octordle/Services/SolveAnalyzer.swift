import Foundation

/// How good a single guess was, relative to the best play available at that moment.
enum GuessRating: Int {
    case soft = 1, fair, good, great, brilliant

    /// Filled dots out of 5.
    var dots: Int { rawValue }

    var label: String {
        switch self {
        case .brilliant: return "Brilliant"
        case .great: return "Great"
        case .good: return "Good"
        case .fair: return "Fair"
        case .soft: return "Soft"
        }
    }
}

/// Analysis of one guess.
struct GuessAnalysis: Identifiable {
    let id = UUID()
    let number: Int            // 1-based
    let word: String
    let ratio: Double          // 0...1, how close to the best available play
    let rating: GuessRating
    let betterAlternative: String?  // a sharper word that was available, if this guess was weak
}

/// The full post-game report. Two scores:
/// - efficiency: how few guesses you used (8 boards solved in 8 = perfect).
/// - skill: how smart your word choices were (information gained vs the best play each turn).
struct SolveReport {
    let isWon: Bool
    let solvedCount: Int
    let totalBoards: Int
    let guessCount: Int
    let maxGuesses: Int

    let efficiency: Int        // 0...100
    let skill: Int             // 0...100
    let headline: String
    let detail: String

    let guesses: [GuessAnalysis]
    let smartestNumber: Int?
    let boardSolvedAt: [Int?]
}

/// Builds a `SolveReport` using information theory: for each guess we measure how much
/// it narrowed the still-possible answers across the boards, and compare that to the
/// best play available at that moment. This is the same idea WordleBot uses.
///
/// Pure value type. Heavier than a trivial pass, so callers should run it off the main thread.
enum SolveAnalyzer {

    // Best opening play, precomputed offline against the current answer pool.
    // (RAISE minimises expected remaining answers; ~5.32 bits of information.)
    // If `words.json` solutions change, recompute via the offline opener script.
    private static let bestOpenerInfoBits = 5.3191
    private static let bestOpenerWord = "RAISE"

    /// Standard Wordle feedback as a base-3 code (0 absent, 1 present, 2 correct).
    private static func code(_ g: [UInt8], _ t: [UInt8]) -> Int {
        var counts = [Int](repeating: 0, count: 26)
        for c in t { counts[Int(c) - 65] += 1 }
        var r = [0, 0, 0, 0, 0]
        for i in 0..<5 where g[i] == t[i] {
            r[i] = 2; counts[Int(g[i]) - 65] -= 1
        }
        for i in 0..<5 where r[i] != 2 {
            let x = Int(g[i]) - 65
            if counts[x] > 0 { r[i] = 1; counts[x] -= 1 }
        }
        return (((r[0] * 3 + r[1]) * 3 + r[2]) * 3 + r[3]) * 3 + r[4]
    }

    /// Expected information (bits) a guess extracts from a board's candidate set.
    private static func infoBits(_ guess: [UInt8], _ candidateIdxs: [Int], _ pool: [[UInt8]]) -> Double {
        let n = candidateIdxs.count
        if n <= 1 { return 0 }
        var buckets = [Int](repeating: 0, count: 243)
        for idx in candidateIdxs { buckets[code(guess, pool[idx])] += 1 }
        var expected = 0.0
        for b in buckets where b > 0 { expected += Double(b) * Double(b) }
        expected /= Double(n)
        return log2(Double(n)) - log2(expected)
    }

    /// Find the highest-information word among `unionIdxs`, scored as the sum of
    /// information gained across each active board's candidate set.
    /// The search is independent per word, so it is fanned out across cores via
    /// `concurrentPerform`. Ties are broken by lowest pool index for a stable,
    /// reproducible result regardless of how work is scheduled.
    private static func bestPlay(unionIdxs: [Int],
                                 activeCandidates: [[Int]],
                                 pool: [[UInt8]]) -> (idx: Int?, info: Double) {
        let count = unionIdxs.count
        if count == 0 { return (nil, 0.0) }

        // Split work into chunks; each core computes a local best, then we reduce.
        let chunkCount = min(count, max(1, ProcessInfo.processInfo.activeProcessorCount))
        let chunkSize = (count + chunkCount - 1) / chunkCount

        var localBestInfo = [Double](repeating: -1.0, count: chunkCount)
        var localBestIdx = [Int](repeating: -1, count: chunkCount)

        localBestInfo.withUnsafeMutableBufferPointer { infoBuf in
            localBestIdx.withUnsafeMutableBufferPointer { idxBuf in
                DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
                    let start = chunk * chunkSize
                    let end = min(start + chunkSize, count)
                    if start >= end { return }

                    // Thread-local scratch buffers — reused across this chunk's words
                    // to avoid per-call allocation in the hot loop.
                    var counts = [Int](repeating: 0, count: 26)
                    var buckets = [Int](repeating: 0, count: 243)

                    var bestInfo = -1.0
                    var bestIdx = -1
                    for u in start..<end {
                        let gIdx = unionIdxs[u]
                        let g = pool[gIdx]
                        var info = 0.0
                        for cand in activeCandidates {
                            info += infoBits(g, cand, pool, &counts, &buckets)
                        }
                        // Lowest pool index wins ties for determinism.
                        if info > bestInfo || (info == bestInfo && gIdx < bestIdx) {
                            bestInfo = info
                            bestIdx = gIdx
                        }
                    }
                    infoBuf[chunk] = bestInfo
                    idxBuf[chunk] = bestIdx
                }
            }
        }

        var bestInfo = 0.0
        var bestIdx: Int? = nil
        for c in 0..<chunkCount where localBestIdx[c] >= 0 {
            let info = localBestInfo[c]
            let idx = localBestIdx[c]
            if info > bestInfo || (bestIdx != nil && info == bestInfo && idx < bestIdx!) {
                bestInfo = info
                bestIdx = idx
            }
        }
        return (bestIdx, bestInfo)
    }

    /// Buffer-reusing variant of `infoBits` for the hot parallel search path.
    /// `counts`/`buckets` are caller-owned scratch space, zeroed on each call.
    private static func infoBits(_ guess: [UInt8], _ candidateIdxs: [Int], _ pool: [[UInt8]],
                                 _ counts: inout [Int], _ buckets: inout [Int]) -> Double {
        let n = candidateIdxs.count
        if n <= 1 { return 0 }
        for i in 0..<243 { buckets[i] = 0 }
        for idx in candidateIdxs {
            let t = pool[idx]
            for i in 0..<26 { counts[i] = 0 }
            for c in t { counts[Int(c) - 65] += 1 }
            var r0 = 0, r1 = 0, r2 = 0, r3 = 0, r4 = 0
            // correct (2)
            if guess[0] == t[0] { r0 = 2; counts[Int(guess[0]) - 65] -= 1 }
            if guess[1] == t[1] { r1 = 2; counts[Int(guess[1]) - 65] -= 1 }
            if guess[2] == t[2] { r2 = 2; counts[Int(guess[2]) - 65] -= 1 }
            if guess[3] == t[3] { r3 = 2; counts[Int(guess[3]) - 65] -= 1 }
            if guess[4] == t[4] { r4 = 2; counts[Int(guess[4]) - 65] -= 1 }
            // present (1)
            if r0 != 2 { let x = Int(guess[0]) - 65; if counts[x] > 0 { r0 = 1; counts[x] -= 1 } }
            if r1 != 2 { let x = Int(guess[1]) - 65; if counts[x] > 0 { r1 = 1; counts[x] -= 1 } }
            if r2 != 2 { let x = Int(guess[2]) - 65; if counts[x] > 0 { r2 = 1; counts[x] -= 1 } }
            if r3 != 2 { let x = Int(guess[3]) - 65; if counts[x] > 0 { r3 = 1; counts[x] -= 1 } }
            if r4 != 2 { let x = Int(guess[4]) - 65; if counts[x] > 0 { r4 = 1; counts[x] -= 1 } }
            let pattern = (((r0 * 3 + r1) * 3 + r2) * 3 + r3) * 3 + r4
            buckets[pattern] += 1
        }
        var expected = 0.0
        for b in buckets where b > 0 { expected += Double(b) * Double(b) }
        expected /= Double(n)
        return log2(Double(n)) - log2(expected)
    }

    static func analyze(gameState: GameState, pool rawPool: [String]) -> SolveReport {
        let boards = gameState.boards
        let boardCount = boards.count
        let pool: [[UInt8]] = rawPool.map { Array($0.uppercased().utf8) }
        let targets: [[UInt8]] = boards.map { Array($0.targetWord.uppercased().utf8) }
        let solvedAt = boards.map { $0.solvedAtGuess }

        // Ordered guess words come from the board with the most rows (solved last / unsolved).
        let guessWords: [String] = (boards.max(by: { $0.guesses.count < $1.guesses.count })?.guesses ?? [])
            .map { row in row.map { $0.letter }.joined().uppercased() }

        // Per-board candidate sets, as indices into `pool`.
        var candidates: [[Int]] = Array(repeating: Array(pool.indices), count: boardCount)

        var analyses: [GuessAnalysis] = []
        var totalPlayerInfo = 0.0
        var totalBestInfo = 0.0

        for (idx, word) in guessWords.enumerated() {
            let number = idx + 1
            let guessBytes = Array(word.uppercased().utf8)
            let activeBoards = (0..<boardCount).filter { solvedAt[$0] == nil || solvedAt[$0]! >= number }

            // Player info this turn = sum across active boards.
            var playerInfo = 0.0
            for b in activeBoards { playerInfo += infoBits(guessBytes, candidates[b], pool) }

            // Best info available this turn.
            var bestInfo = 0.0
            var bestWord: String? = nil

            if number == 1 {
                // All boards start from the full pool; best opener is precomputed.
                bestInfo = Double(activeBoards.count) * bestOpenerInfoBits
                bestWord = bestOpenerWord
            } else {
                // Search the words that could still be answers (union of candidates).
                var unionSet = Set<Int>()
                for b in activeBoards { unionSet.formUnion(candidates[b]) }
                let unionIdxs = Array(unionSet)
                let activeCandidates = activeBoards.map { candidates[$0] }

                // Each union word's score is independent — fan out across cores.
                let (idx, info) = bestPlay(unionIdxs: unionIdxs,
                                           activeCandidates: activeCandidates,
                                           pool: pool)
                bestInfo = info
                if let idx { bestWord = String(decoding: pool[idx], as: UTF8.self) }
            }

            let ratio: Double = bestInfo > 0.0001 ? min(1.0, playerInfo / bestInfo) : 1.0
            let rating = ratingFor(ratio)
            // Suggest a sharper word only when the guess was clearly suboptimal.
            let alt: String? = (rating.rawValue <= GuessRating.fair.rawValue
                                && bestWord != nil
                                && bestWord! != word) ? bestWord : nil

            analyses.append(GuessAnalysis(number: number, word: word, ratio: ratio, rating: rating, betterAlternative: alt))

            if bestInfo > 0.0001 {
                totalPlayerInfo += playerInfo
                totalBestInfo += bestInfo
            }

            // Apply the actual guess: filter each active board's candidates.
            for b in activeBoards {
                let actual = code(guessBytes, targets[b])
                candidates[b] = candidates[b].filter { code(guessBytes, pool[$0]) == actual }
            }
        }

        let skill = totalBestInfo > 0 ? Int((100.0 * totalPlayerInfo / totalBestInfo).rounded()) : 100
        let solvedCount = boards.filter { $0.isSolved }.count
        let efficiency = efficiencyScore(isWon: gameState.isWon, solvedCount: solvedCount,
                                         boardCount: boardCount, guessCount: gameState.guessCount,
                                         maxGuesses: gameState.difficulty.maxGuesses)

        // Smartest guess = highest quality ratio (ties broken by earliest).
        let smartest = analyses.max(by: { $0.ratio < $1.ratio })
        let smartestNumber = (smartest?.ratio ?? 0) > 0.0001 ? smartest?.number : nil

        let (headline, detail) = verdict(skill: skill, isWon: gameState.isWon,
                                         solvedCount: solvedCount, boardCount: boardCount,
                                         guessCount: gameState.guessCount)

        return SolveReport(
            isWon: gameState.isWon,
            solvedCount: solvedCount,
            totalBoards: boardCount,
            guessCount: gameState.guessCount,
            maxGuesses: gameState.difficulty.maxGuesses,
            efficiency: efficiency,
            skill: skill,
            headline: headline,
            detail: detail,
            guesses: analyses,
            smartestNumber: smartestNumber,
            boardSolvedAt: solvedAt
        )
    }

    // MARK: - Scoring helpers

    private static func ratingFor(_ ratio: Double) -> GuessRating {
        switch ratio {
        case 0.92...: return .brilliant
        case 0.80..<0.92: return .great
        case 0.65..<0.80: return .good
        case 0.45..<0.65: return .fair
        default: return .soft
        }
    }

    /// Efficiency = guess economy. Solving every board in the minimum number of
    /// guesses (one per board) is a perfect 100; each extra guess costs points,
    /// and any win stays at 50+.
    private static func efficiencyScore(isWon: Bool, solvedCount: Int, boardCount: Int,
                                        guessCount: Int, maxGuesses: Int) -> Int {
        guard isWon else {
            return Int((50.0 * Double(solvedCount) / Double(boardCount)).rounded())
        }
        let floor = boardCount
        let span = max(1, maxGuesses - floor)
        let penaltyPerGuess = 50.0 / Double(span)
        let raw = 100.0 - Double(max(0, guessCount - floor)) * penaltyPerGuess
        return Int(min(100.0, max(50.0, raw)).rounded())
    }

    private static func verdict(skill: Int, isWon: Bool, solvedCount: Int,
                                boardCount: Int, guessCount: Int) -> (String, String) {
        let detail = isWon
            ? "Solved all \(boardCount) boards in \(guessCount) guesses."
            : "Solved \(solvedCount) of \(boardCount) boards."

        if !isWon {
            return ("A tough one — but some sharp guessing in there.", detail)
        }
        let headline: String
        switch skill {
        case 90...: headline = "Brilliant word choices."
        case 75..<90: headline = "Sharp, efficient guessing."
        case 60..<75: headline = "Solid choices throughout."
        case 45..<60: headline = "Nicely done — a few sharper options were there."
        default: headline = "Got the win. Plenty of room to sharpen up."
        }
        return (headline, detail)
    }
}
