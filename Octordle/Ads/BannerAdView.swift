import SwiftUI
import GoogleMobileAds

// MARK: - Banner Ad View (UIViewRepresentable)
struct BannerAdView: UIViewRepresentable {

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = Constants.AdMob.bannerAdUnitId
        bannerView.rootViewController = getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        private var retryCount = 0
        private let maxRetries = 3

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[AdMob] Banner ad loaded successfully")
            retryCount = 0
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Banner ad failed to load: \(error.localizedDescription)")
            guard retryCount < maxRetries else { return }
            let delay = pow(2.0, Double(retryCount + 1)) // 2s, 4s, 8s
            retryCount += 1
            print("[AdMob] Retrying banner in \(delay)s (attempt \(retryCount)/\(maxRetries))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                bannerView.load(GADRequest())
            }
        }
    }
}

// MARK: - Adaptive Banner Ad View
struct AdaptiveBannerAdView: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView()
        bannerView.adUnitID = Constants.AdMob.bannerAdUnitId
        bannerView.rootViewController = getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[AdMob] Adaptive banner ad loaded successfully")
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Adaptive banner ad failed to load: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BannerAdView()
        .frame(height: 50)
}
