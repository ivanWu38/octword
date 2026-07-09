import Foundation

/// Which family a Challenge preset belongs to.
enum ChallengeFamily: String, Codable {
    case timed
    case run
}

/// A single Challenge preset. Challenges are consecutive Unlimited-style rounds
/// (8 boards, `Constants.Game.defaultDifficulty`).
///
/// - `.timed`: finish `gameTarget` games before the clock (`config` seconds) runs
///   out. Beat the target → the challenge is *completed*; run out of time first →
///   it just ends. Score = total boards solved.
/// - `.run`: keep playing on a shared life pool (`config` lives); each unsolved
///   board costs a life. Survive as long as you can. Score = total boards solved.
struct ChallengeType: Identifiable, Equatable {
    let id: String
    let family: ChallengeFamily
    let name: String
    let subtitle: String
    let symbol: String
    /// Seconds of clock for `.timed`, number of lives for `.run`.
    let config: Int
    /// Number of games to complete within the clock (`.timed` only; 0 for `.run`).
    let gameTarget: Int

    /// Guesses per round in Run mode — tighter than the standard budget so failing
    /// a board (and losing a life) is a genuine risk, otherwise runs never end.
    static let runGuessesPerRound = 10

    // MARK: Timed — complete N games before the clock runs out

    static let timedQuick = ChallengeType(
        id: "timed_quick", family: .timed, name: "Flash",
        subtitle: "3 min · 1 game", symbol: "bolt", config: 3 * 60, gameTarget: 1
    )
    static let timedStandard = ChallengeType(
        id: "timed_standard", family: .timed, name: "Bulletin",
        subtitle: "10 min · 2 games", symbol: "megaphone", config: 10 * 60, gameTarget: 2
    )
    static let timedExtended = ChallengeType(
        id: "timed_extended", family: .timed, name: "Column",
        subtitle: "25 min · 4 games", symbol: "doc.plaintext", config: 25 * 60, gameTarget: 4
    )
    static let timedMarathon = ChallengeType(
        id: "timed_marathon", family: .timed, name: "Feature",
        subtitle: "45 min · 6 games", symbol: "doc.richtext", config: 45 * 60, gameTarget: 6
    )
    static let timedUltra = ChallengeType(
        id: "timed_ultra", family: .timed, name: "Front Page",
        subtitle: "90 min · 10 games", symbol: "newspaper", config: 90 * 60, gameTarget: 10
    )

    // MARK: Run — survive on a shared life pool

    static let runSudden = ChallengeType(
        id: "run_sudden", family: .run, name: "Stop Press",
        subtitle: "1 life · one slip ends it", symbol: "heart.slash", config: 1, gameTarget: 0
    )
    static let runSprint = ChallengeType(
        id: "run_sprint", family: .run, name: "Print Run",
        subtitle: "3 lives · a quick run", symbol: "bolt.heart", config: 3, gameTarget: 0
    )
    static let runClassic = ChallengeType(
        id: "run_classic", family: .run, name: "Daily Grind",
        subtitle: "5 lives · standard survival", symbol: "figure.run", config: 5, gameTarget: 0
    )
    static let runSurvivor = ChallengeType(
        id: "run_survivor", family: .run, name: "Circulation",
        subtitle: "10 lives · go the distance", symbol: "shield.lefthalf.filled", config: 10, gameTarget: 0
    )
    static let runGauntlet = ChallengeType(
        id: "run_gauntlet", family: .run, name: "The Long Read",
        subtitle: "15 lives · the ultimate test", symbol: "flame", config: 15, gameTarget: 0
    )

    static let timedPresets: [ChallengeType] = [.timedQuick, .timedStandard, .timedExtended, .timedMarathon, .timedUltra]
    static let runPresets: [ChallengeType] = [.runSudden, .runSprint, .runClassic, .runSurvivor, .runGauntlet]
    static let all: [ChallengeType] = timedPresets + runPresets
}
