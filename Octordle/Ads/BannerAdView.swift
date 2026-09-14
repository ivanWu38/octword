import SwiftUI
import GoogleMobileAds

// MARK: - Banner Ad View (UIViewRepresentable)
struct BannerAdView: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = Constants.AdMob.bannerAdUnitId
        bannerView.rootViewController = getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

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

    class Coordinator: NSObject, BannerViewDelegate {
        private var retryCount = 0
        private let maxRetries = 3

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] Banner ad loaded successfully")
            retryCount = 0
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Banner ad failed to load: \(error.localizedDescription)")
            guard retryCount < maxRetries else { return }
            let delay = pow(2.0, Double(retryCount + 1)) // 2s, 4s, 8s
            retryCount += 1
            print("[AdMob] Retrying banner in \(delay)s (attempt \(retryCount)/\(maxRetries))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                bannerView.load(Request())
            }
        }
    }
}

// MARK: - Adaptive Banner Ad View
struct AdaptiveBannerAdView: UIViewRepresentable {
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView()
        bannerView.adUnitID = Constants.AdMob.bannerAdUnitId
        bannerView.rootViewController = getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

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

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] Adaptive banner ad loaded successfully")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Adaptive banner ad failed to load: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BannerAdView()
        .frame(height: 50)
}
