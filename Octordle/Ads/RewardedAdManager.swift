import GoogleMobileAds
import UIKit

/// Manages rewarded ad loading, presentation, and reward tracking.
/// Used to unlock individual archive puzzles.
@MainActor
class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager(adUnitId: Constants.AdMob.rewardedAdUnitId)
    /// Dedicated instance for the "buy me a coffee" support flow (separate ad unit).
    static let support = RewardedAdManager(adUnitId: Constants.AdMob.supportRewardedAdUnitId)
    /// Dedicated instance for unlocking themed-category levels (separate ad unit).
    static let category = RewardedAdManager(adUnitId: Constants.AdMob.categoryRewardedAdUnitId)

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
        // If the ad isn't ready, wait up to 8 seconds for it to load (a cold load on
        // first open can take a few seconds, so give it room before giving up).
        if !isAdReady {
            preloadIfNeeded()
            for _ in 0..<80 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if isAdReady { break }
            }
        }

        guard let rewardedAd else {
            print("[AdMob] No rewarded ad available after waiting (\(adUnitId))")
            return false
        }

        pendingRewardEarned = false

        // Any triggering sheet (e.g. the locked-pack sheet) is usually dismissing
        // right now. Presenting on a view controller that is mid-dismissal fails
        // silently AND never calls the delegate — which would hang the caller
        // forever. So wait for a stable presenter that is on-screen and not being
        // dismissed before presenting.
        guard let topVC = await stablePresenter() else {
            print("[AdMob] No stable presenter found — skipping ad (\(adUnitId))")
            return false
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            rewardedAd.present(fromRootViewController: topVC) { [weak self] in
                print("[AdMob] User earned reward")
                self?.pendingRewardEarned = true
            }
        }
    }

    /// Resolve the top-most view controller that is actually on-screen and not in
    /// the middle of a presentation/dismissal transition. Polls briefly so a sheet
    /// that is currently dismissing has time to finish first.
    private func stablePresenter() async -> UIViewController? {
        for attempt in 0..<25 { // up to ~2.5s
            if attempt > 0 { try? await Task.sleep(nanoseconds: 100_000_000) }

            guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene),
                  let rootVC = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController else {
                continue
            }

            // Walk down to the deepest presented VC, but never step onto one that
            // is being dismissed (that's the transient sheet we're waiting out).
            var topVC = rootVC
            while let presented = topVC.presentedViewController, !presented.isBeingDismissed {
                topVC = presented
            }

            // The presenter must have NOTHING currently presented on it, or the
            // present call fails with "already presenting another view controller".
            // A non-nil presentedViewController here means a sheet is still mid-
            // dismissal — wait for it to finish.
            if topVC.presentedViewController != nil
                || topVC.isBeingPresented || topVC.isBeingDismissed
                || topVC.view.window == nil {
                continue // still transitioning — wait and retry
            }
            return topVC
        }
        return nil
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
