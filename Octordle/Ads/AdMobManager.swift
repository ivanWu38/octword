import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob manager for handling ads
@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()

    @Published var isAdsInitialized = false

    private override init() {
        super.init()
    }

    // MARK: - SDK Initialization

    /// Initialize AdMob SDK — only if UMP consent allows ad requests
    nonisolated func initialize() {
        var diag = false
        #if DEBUG
        diag = ProcessInfo.processInfo.environment["OCTORDLE_AD_DIAG"] == "1"
        #endif
        guard ConsentInformation.shared.canRequestAds || diag else {
            print("[AdMob] Cannot request ads — consent not obtained, skipping initialization")
            return
        }

        MobileAds.shared.start { status in
            print("[AdMob] SDK initialized")
            // Mediation health: every adapter the server-side config asked us to init.
            for (adapter, st) in status.adapterStatusesByClassName.sorted(by: { $0.key < $1.key }) {
                print("[AdsDiag] adapter \(adapter): \(st.state == .ready ? "READY" : "NOT READY") latency=\(st.latency)s \(st.description)")
            }
            Task { @MainActor in
                self.isAdsInitialized = true
                #if DEBUG
                if diag { self.runMediationDiagnostics() }
                if ProcessInfo.processInfo.environment["OCTORDLE_AD_INSPECTOR"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        MobileAds.shared.presentAdInspector(from: nil) { error in print("[Ads] Ad Inspector closed: \(error?.localizedDescription ?? "ok")") }
                    }
                }
                #endif
            }
        }
    }

}

// MARK: - Mediation diagnostics (DEBUG only, launch env OCTORDLE_AD_DIAG=1 + OCTORDLE_PROD_ADS=1)

#if DEBUG
extension AdMobManager {
    private static func describe(_ info: ResponseInfo?, label: String) {
        guard let info else { print("[AdsDiag] \(label): no responseInfo"); return }
        print("[AdsDiag] \(label): responseId=\(info.responseIdentifier ?? "-") winner=\(info.loadedAdNetworkResponseInfo?.adNetworkClassName ?? "-")")
        for n in info.adNetworkInfoArray { print("[AdsDiag]   network \(n.adNetworkClassName) latency=\(n.latency)s error=\(n.error?.localizedDescription ?? "none")") }
    }
    private static func responseInfo(from error: Error) -> ResponseInfo? { (error as NSError).userInfo["gad_response_info"] as? ResponseInfo }

    /// Load every production unit once and print which networks were asked.
    func runMediationDiagnostics() {
        let rewardedUnits: [(String, String)] = [
            ("rewarded", Constants.AdMob.rewardedAdUnitId),
            ("supportRewarded", Constants.AdMob.supportRewardedAdUnitId),
            ("packRewarded", Constants.AdMob.categoryRewardedAdUnitId),
            ("streakRescueRewarded", Constants.AdMob.streakRescueRewardedAdUnitId),
        ]
        for (label, unit) in rewardedUnits {
            RewardedAd.load(with: unit, request: Request()) { ad, error in
                if let error { print("[AdsDiag] \(label) FAILED: \(error.localizedDescription)"); Self.describe(Self.responseInfo(from: error), label: label) }
                else { Self.describe(ad?.responseInfo, label: label) }
            }
        }
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = Constants.AdMob.bannerAdUnitId
        banner.delegate = DiagBannerDelegate.shared
        DiagBannerDelegate.shared.retained = banner
        banner.load(Request())
    }

    private final class DiagBannerDelegate: NSObject, BannerViewDelegate {
        static let shared = DiagBannerDelegate()
        var retained: BannerView?
        func bannerViewDidReceiveAd(_ bannerView: BannerView) { AdMobManager.describe(bannerView.responseInfo, label: "banner") }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdsDiag] banner FAILED: \(error.localizedDescription)"); AdMobManager.describe(AdMobManager.responseInfo(from: error), label: "banner")
        }
    }
}
#endif
