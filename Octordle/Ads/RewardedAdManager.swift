import GoogleMobileAds
import UIKit

/// Manages rewarded ad loading, presentation, and reward tracking.
/// Used to unlock individual archive puzzles.
@MainActor
class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager(adUnitId: Constants.AdMob.rewardedAdUnitId)

    @Published private(set) var isAdReady = false

    private let adUnitId: String
    private var rewardedAd: GADRewardedAd?
    private var retryCount = 0
    private let maxRetries = 3
    private var pendingRewardEarned = false
    private var continuation: CheckedContinuation<Bool, Never>?
    private var isLoading = false

    private init(adUnitId: String) {
        self.adUnitId = adUnitId
        super.init()
    }

    // MARK: - Preload

    /// Preload a rewarded ad if one isn't already loaded or loading.
    func preloadIfNeeded() {
        guard !isAdReady && !isLoading else { return }
        loadAd()
    }

    // MARK: - Load

    func loadAd() {
        guard !isLoading else { return }
        isLoading = true
        retryCount = 0
        loadAdInternal()
    }

    private func loadAdInternal() {
        GADRewardedAd.load(withAdUnitID: adUnitId, request: GADRequest()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let ad {
                    print("[AdMob] Rewarded ad loaded (\(self.adUnitId))")
                    self.rewardedAd = ad
                    self.rewardedAd?.fullScreenContentDelegate = self
                    self.isAdReady = true
                    self.retryCount = 0
                } else {
                    print("[AdMob] Rewarded ad failed to load (\(self.adUnitId)): \(error?.localizedDescription ?? "unknown")")
                    self.isAdReady = false
                    guard self.retryCount < self.maxRetries else { return }
                    let delay = pow(2.0, Double(self.retryCount + 1))
                    self.retryCount += 1
                    self.isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.loadAdInternal()
                    }
                }
            }
        }
    }

    // MARK: - Show

    /// Show the ad, waiting briefly for it to load if needed.
    /// Returns `true` if the user earned the reward.
    func showAd() async -> Bool {
        // If the ad isn't ready, wait up to 3 seconds for it to load
        if !isAdReady {
            preloadIfNeeded()
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if isAdReady { break }
            }
        }

        guard let rewardedAd else {
            print("[AdMob] No rewarded ad available after waiting (\(adUnitId))")
            return false
        }

        pendingRewardEarned = false

        // Wait briefly for any sheet/alert dismissal animation to settle
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Present from the TOPMOST presented view controller (e.g. above the unlock sheet)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController else {
            print("[AdMob] No root view controller found")
            return false
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            rewardedAd.present(fromRootViewController: topVC) { [weak self] in
                print("[AdMob] User earned reward")
                self?.pendingRewardEarned = true
            }
        }
    }

    // MARK: - Reset

    func reset() {
        rewardedAd = nil
        isAdReady = false
        isLoading = false
        retryCount = 0
        pendingRewardEarned = false
        continuation?.resume(returning: false)
        continuation = nil
    }
}

// MARK: - GADFullScreenContentDelegate

extension RewardedAdManager: GADFullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            let earned = pendingRewardEarned
            rewardedAd = nil
            isAdReady = false
            isLoading = false
            continuation?.resume(returning: earned)
            continuation = nil
            loadAd() // auto-load the next one
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[AdMob] Rewarded ad failed to present: \(error.localizedDescription)")
            rewardedAd = nil
            isAdReady = false
            isLoading = false
            continuation?.resume(returning: false)
            continuation = nil
            loadAd()
        }
    }
}
