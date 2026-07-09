import Foundation

/// Which family a Challenge preset belongs to.
enum ChallengeFamily: String, Codable {
    case timed
    case run
}

/// A single Challenge preset. Challenges are consecutive Unlimited-style rounds
/// (8 boards, `Constants.Game.defaultDifficulty`) played back-to-back against a
/// shared time budget (`.timed`) or life pool (`.run`). Score = total boards
/// solved across every round played in the session.
struct ChallengeType: Identifiable, Equatable {
    let id: String
    let family: ChallengeFamily
    let name: String
    let subtitle: String
    let symbol: String
    /// Seconds of clock for `.timed`, number of lives for `.run`.
    let config: Int

    static let timedQuick = ChallengeType(
        id: "timed_quick", family: .timed, name: "Quick",
        subtitle: "3 minutes · beat the clock", symbol: "hare", config: 3 * 60
    )
    static let timedStandard = ChallengeType(
        id: "timed_standard", family: .timed, name: "Standard",
        subtitle: "10 minutes · beat the clock", symbol: "stopwatch", config: 10 * 60
    )
    static let timedMarathon = ChallengeType(
        id: "timed_marathon", family: .timed, name: "Marathon",
        subtitle: "30 minutes · beat the clock", symbol: "flag.checkered", config: 30 * 60
    )

    static let runSprint = ChallengeType(
        id: "run_sprint", family: .run, name: "Sprint",
        subtitle: "3 lives · survive", symbol: "bolt.heart", config: 3
    )
    static let runClassic = ChallengeType(
        id: "run_classic", family: .run, name: "Classic",
        subtitle: "5 lives · survive", symbol: "figure.run", config: 5
    )
    static let runSurvivor = ChallengeType(
        id: "run_survivor", family: .run, name: "Survivor",
        subtitle: "10 lives · survive", symbol: "shield.lefthalf.filled", config: 10
    )

    static let timedPresets: [ChallengeType] = [.timedQuick, .timedStandard, .timedMarathon]
    static let runPresets: [ChallengeType] = [.runSprint, .runClassic, .runSurvivor]
    static let all: [ChallengeType] = timedPresets + runPresets
}
