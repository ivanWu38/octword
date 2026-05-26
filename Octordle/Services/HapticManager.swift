import UIKit
import AudioToolbox

/// Haptic and sound feedback manager
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

    /// Key tap feedback - light tap for each key press
    func keyTap() {
        light()
    }

    /// Delete key feedback - slightly stronger than regular key
    func deleteTap() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.7)
    }

    /// Submit guess feedback - medium impact when submitting
    func submitGuess() {
        medium()
    }

    /// Invalid word feedback - error notification
    func invalidWord() {
        error()
        playSound(.error)
    }

    /// Not enough letters feedback - warning shake
    func notEnoughLetters() {
        warning()
    }

    /// Board solved feedback - success with celebration
    func boardSolved() {
        success()
        playSound(.success)
    }

    /// Letter in correct position (blue) - positive feedback
    func letterCorrect() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    /// Letter in wrong position (purple) - subtle feedback
    func letterPresent() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.4)
    }

    /// Game won feedback - celebration pattern
    func gameWon() {
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.medium()
        }
        playSound(.fanfare)
    }

    /// Game lost feedback
    func gameLost() {
        warning()
        playSound(.error)
    }

    /// Perfect game feedback - extra celebration
    func perfectGame() {
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
        playSound(.fanfare)
    }

    // MARK: - UI Interaction Feedback

    /// Tab switch feedback
    func tabSwitch() {
        guard isHapticEnabled else { return }
        mediumGenerator.impactOccurred(intensity: 0.7)
    }

    /// Button tap feedback - general buttons
    func buttonTap() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.5)
    }

    /// Toggle switch feedback
    func toggleSwitch() {
        guard isHapticEnabled else { return }
        mediumGenerator.impactOccurred(intensity: 0.6)
    }

    /// Difficulty selection feedback
    func difficultySelect() {
        medium()
    }

    /// Game start feedback - anticipation
    func gameStart() {
        guard isHapticEnabled else { return }
        mediumGenerator.impactOccurred(intensity: 0.7)
        playSound(.click)
    }

    /// Navigation feedback
    func navigate() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.4)
    }

    /// Pull to refresh feedback
    func pullRefresh() {
        medium()
    }

    // MARK: - Achievement & Milestone Feedback

    /// Achievement unlocked feedback - celebration pattern
    func achievementUnlocked() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.mediumGenerator.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.lightGenerator.impactOccurred(intensity: 0.5)
        }
        playSound(.fanfare)
    }

    /// Streak milestone feedback (7 days, 30 days, etc.)
    func streakMilestone() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.success()
        }
        playSound(.success)
    }

    /// Streak +1 feedback - lighter than milestone, used for the daily increment animation
    func streakIncrement() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.mediumGenerator.impactOccurred(intensity: 0.6)
        }
    }

    /// New personal best feedback
    func newPersonalBest() {
        guard isHapticEnabled else { return }
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.heavy()
        }
        playSound(.fanfare)
    }

    // MARK: - Countdown Feedback

    /// Countdown tick feedback (for last few seconds)
    func countdownTick() {
        guard isHapticEnabled else { return }
        lightGenerator.impactOccurred(intensity: 0.3)
    }

    /// Countdown complete feedback
    func countdownComplete() {
        success()
        playSound(.success)
    }

    // MARK: - Sound Effects

    enum SoundType {
        case success
        case error
        case fanfare
        case click

        var systemSoundID: SystemSoundID {
            switch self {
            case .success: return 1025
            case .error: return 1053
            case .fanfare: return 1026
            case .click: return 1104
            }
        }
    }

    func playSound(_ sound: SoundType) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
}
