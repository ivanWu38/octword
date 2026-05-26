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
        guard UMPConsentInformation.sharedInstance.canRequestAds else {
            print("[AdMob] Cannot request ads — consent not obtained, skipping initialization")
            return
        }

        GADMobileAds.sharedInstance().start { status in
            print("[AdMob] SDK initialized")
            Task { @MainActor in
                self.isAdsInitialized = true
            }
        }
    }

}
