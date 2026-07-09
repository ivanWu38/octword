import UIKit
import AVFoundation

/// Plays the app's custom sound effects (bundled .m4a clips under Resources/Sounds).
///
/// Design notes:
/// - Some effects have several variants that are cycled round-robin so repeats don't
///   sound identical (`click` ×5, `insert` ×3, `tab` ×6).
/// - Each clip gets a small pool of preloaded `AVAudioPlayer`s so rapid fire
///   (typing, tapping) can overlap instead of cutting itself off.
/// - Uses the `.ambient` audio session so we never interrupt the user's music and
///   we honor the hardware mute switch.
/// - Gated by the same `octordle_soundEnabled` flag as before.
final class SoundManager {
    static let shared = SoundManager()

    enum Effect: Hashable {
        // The 5 distinct clicks in click.wav, each fixed to one kind of action
        // (no more round-robin — a given action always sounds the same).
        case tap        // general interface button → click_1
        case tab        // bottom tab switch → click_2
        case back       // back / close / cancel → click_3
        case primary    // primary / confirm action → click_4
        case card       // tapping a card or list item → click_5

        case type       // typing a letter on the game keyboard
        case insert     // a board just got solved
        case error      // invalid word entered
        case solved     // puzzle cleared / theme unlocked

        /// Sound file for this effect (single fixed clip per effect).
        var files: [String] {
            switch self {
            case .tap:     return ["click_1"]
            case .tab:     return ["click_2"]
            case .back:    return ["click_3"]
            case .primary: return ["click_4"]
            case .card:    return ["click_5"]
            case .insert:  return ["insert"]
            case .type:    return ["type"]
            case .error:   return ["error"]
            case .solved:  return ["solved"]
            }
        }

        /// Per-effect playback volume (UI ticks sit lower than celebrations).
        var volume: Float {
            switch self {
            case .tap, .tab, .back, .card, .type: return 0.65
            case .primary: return 0.75
            case .insert:  return 0.8
            case .error:   return 0.9
            case .solved:  return 1.0
            }
        }
    }

    private let voicesPerFile = 2
    private var pools: [String: [AVAudioPlayer]] = [:]   // file name → preloaded players
    private var poolCursor: [String: Int] = [:]          // round-robin within a file's pool
    private var variantCursor: [Effect: Int] = [:]       // round-robin across an effect's variants

    private(set) var isSoundEnabled: Bool =
        UserDefaults.standard.object(forKey: "octordle_soundEnabled") as? Bool ?? true

    private init() {
        configureSession()
        preloadAll()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func url(for file: String) -> URL? {
        Bundle.main.url(forResource: file, withExtension: "m4a", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: file, withExtension: "m4a")
    }

    private func preloadAll() {
        let effects: [Effect] = [.tap, .tab, .back, .primary, .card, .type, .insert, .error, .solved]
        for effect in effects {
            for file in effect.files {
                guard let url = url(for: file) else { continue }
                var players: [AVAudioPlayer] = []
                for _ in 0..<voicesPerFile {
                    if let p = try? AVAudioPlayer(contentsOf: url) {
                        p.volume = effect.volume
                        p.prepareToPlay()
                        players.append(p)
                    }
                }
                if !players.isEmpty { pools[file] = players }
            }
        }
    }

    func reloadSettings() {
        isSoundEnabled = UserDefaults.standard.object(forKey: "octordle_soundEnabled") as? Bool ?? true
    }

    /// Play an effect — picks the next variant, then an idle (or oldest) voice from
    /// that clip's pool so overlapping calls don't clip each other.
    func play(_ effect: Effect) {
        guard isSoundEnabled else { return }

        let files = effect.files
        guard !files.isEmpty else { return }
        let vIdx = (variantCursor[effect] ?? 0) % files.count
        variantCursor[effect] = vIdx + 1
        let file = files[vIdx]

        guard let players = pools[file], !players.isEmpty else { return }
        let idle = players.first { !$0.isPlaying }
        let player: AVAudioPlayer
        if let idle {
            player = idle
        } else {
            let c = (poolCursor[file] ?? 0) % players.count
            poolCursor[file] = c + 1
            player = players[c]
        }
        player.currentTime = 0
        player.play()
    }
}

/// Haptic and sound feedback manager. Haptics live here; sound effects are delegated
/// to `SoundManager`. Each public method maps a game event to its haptic + sound.
final class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    /// Cached settings — updated via reloadSettings()
    private(set) var isHapticEnabled: Bool = true
    private(set) var isSoundEnabled: Bool = true

    private init() {
        reloadSettings()
    }

    /// Re-read settings from UserDefaults (call when user changes prefs)
    func reloadSettings() {
        isHapticEnabled = UserDefaults.standard.object(forKey: "octordle_hapticEnabled") as? Bool ?? true
        isSoundEnabled = UserDefaults.standard.object(forKey: "octordle_soundEnabled") as? Bool ?? true
        SoundManager.shared.reloadSettings()
    }

    /// Prepare all generators for immediate feedback
    func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Impact Feedback

    func light() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred()
    }

    func medium() {
        guard isHapticEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    func heavy() {
        guard isHapticEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    // MARK: - Notification Feedback

    func success() {
        guard isHapticEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        guard isHapticEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard isHapticEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    func selection() {
        guard isHapticEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    // MARK: - Game-Specific Feedback

    /// Key tap feedback — typing a letter on the game keyboard.
    func keyTap() {
        light()
        SoundManager.shared.play(.type)
    }

    /// Delete key feedback — also a keyboard action, same typing sound.
    func deleteTap() {
        if isHapticEnabled { lightGenerator.impactOccurred(intensity: 0.7) }
        SoundManager.shared.play(.type)
    }

    /// Submit guess feedback — haptic only; the outcome (board solved / invalid /
    /// win) plays its own sound right after, so submitting itself stays silent.
    func submitGuess() {
        medium()
    }

    /// Invalid word feedback.
    func invalidWord() {
        error()
        SoundManager.shared.play(.error)
    }

    /// Not enough letters feedback — warning shake, no sound.
    func notEnoughLetters() {
        warning()
    }

    /// Board solved feedback.
    func boardSolved() {
        success()
        SoundManager.shared.play(.insert)
    }

    /// Letter in correct position (blue) — positive feedback (typing sound already fired).
    func letterCorrect() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    /// Letter in wrong position (purple) — subtle feedback.
    func letterPresent() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.4)
    }

    /// Game won feedback — the "puzzle cleared" celebration.
    func gameWon() {
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.medium()
        }
        SoundManager.shared.play(.solved)
    }

    /// Game lost feedback — haptic only (loss is intentionally silent).
    func gameLost() {
        warning()
    }

    /// Perfect game feedback — same clear sound, extra haptic flourish.
    func perfectGame() {
        SoundManager.shared.play(.solved)
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.success()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.heavy()
        }
    }

    /// Celebration haptic with NO sound — used where we want the buzz but not the
    /// puzzle-cleared jingle (e.g. buying a coffee).
    func celebrateSilently() {
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavy()
        }
    }

    // MARK: - UI Interaction Feedback
    //
    // The 5 clicks are fixed per action type (no round-robin):
    //   buttonTap → click_1 · tabSwitch → click_2 · backTap → click_3
    //   primaryTap → click_4 · cardTap → click_5

    /// Tab switch feedback — bottom tab change.
    func tabSwitch() {
        if isHapticEnabled { mediumGenerator.impactOccurred(intensity: 0.7) }
        SoundManager.shared.play(.tab)
    }

    /// General interface button tap.
    func buttonTap() {
        if isHapticEnabled { lightGenerator.impactOccurred(intensity: 0.5) }
        SoundManager.shared.play(.tap)
    }

    /// Back / close / cancel button.
    func backTap() {
        if isHapticEnabled { lightGenerator.impactOccurred(intensity: 0.5) }
        SoundManager.shared.play(.back)
    }

    /// Primary / confirm action (Play, Continue, Done, purchase, unlock…).
    func primaryTap() {
        if isHapticEnabled { mediumGenerator.impactOccurred(intensity: 0.7) }
        SoundManager.shared.play(.primary)
    }

    /// Tapping a card or list item to open it (achievement card, pack, challenge,
    /// calendar day, theme/difficulty option…).
    func cardTap() {
        if isHapticEnabled { lightGenerator.impactOccurred(intensity: 0.6) }
        SoundManager.shared.play(.card)
    }

    /// Toggle switch feedback — general control.
    func toggleSwitch() {
        if isHapticEnabled { mediumGenerator.impactOccurred(intensity: 0.6) }
        SoundManager.shared.play(.tap)
    }

    /// Difficulty selection — picking an option card.
    func difficultySelect() {
        medium()
        SoundManager.shared.play(.card)
    }

    /// Game start — a primary action.
    func gameStart() {
        if isHapticEnabled { mediumGenerator.impactOccurred(intensity: 0.7) }
        SoundManager.shared.play(.primary)
    }

    /// Navigation feedback — pushing/popping a screen (treated as a general tap).
    func navigate() {
        if isHapticEnabled { lightGenerator.impactOccurred(intensity: 0.4) }
        SoundManager.shared.play(.tap)
    }

    /// Pull to refresh feedback — haptic only.
    func pullRefresh() {
        medium()
    }

    // MARK: - Achievement & Milestone Feedback

    /// Achievement unlocked — haptic only (achievements are intentionally silent).
    func achievementUnlocked() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.mediumGenerator.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.lightGenerator.impactOccurred(intensity: 0.5)
        }
    }

    /// Streak milestone feedback (7 days, 30 days, etc.) — haptic only.
    func streakMilestone() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.success()
        }
    }

    /// Streak +1 feedback — lighter than milestone, used for the daily increment animation.
    func streakIncrement() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.mediumGenerator.impactOccurred(intensity: 0.6)
        }
    }

    /// New personal best feedback — haptic only.
    func newPersonalBest() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.heavy()
        }
    }

    // MARK: - Countdown Feedback

    /// Countdown tick feedback (for last few seconds).
    func countdownTick() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.3)
    }

    /// Countdown complete feedback — haptic only.
    func countdownComplete() {
        success()
    }
}
