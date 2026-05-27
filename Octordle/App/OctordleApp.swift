import SwiftUI
import GoogleMobileAds
import Clarity
import FirebaseCore
import FirebaseAnalytics
import AppTrackingTransparency

class AppDelegate: NSObject, UIApplicationDelegate {
    private var hasInitializedTrackingSDKs = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure test devices for development
        #if DEBUG
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
            "01da80481aa6bbecc0503354423e83c2"  // Your iPhone test device
        ]
        #endif

        // Initialize Firebase but DISABLE analytics collection until ATT completes
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(false)

        // Do NOT initialize AdMob or Clarity here
        // They will be initialized after UMP consent + ATT flow completes

        return true
    }

    /// Initialize tracking SDKs — called after UMP consent + ATT flow is resolved
    /// Safe to call multiple times; only initializes once
    func initializeTrackingSDKs() {
        guard !hasInitializedTrackingSDKs else { return }
        hasInitializedTrackingSDKs = true

        // Enable Firebase Analytics collection
        Analytics.setAnalyticsCollectionEnabled(true)

        // Initialize AdMob SDK (will check UMP consent internally)
        AdMobManager.shared.initialize()

        // Initialize Microsoft Clarity
        let clarityConfig = ClarityConfig(projectId: "wxg3m4aogx")
        ClaritySDK.initialize(config: clarityConfig)
    }
}

@main
struct OctordleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeService = ThemeService.shared
    @StateObject private var statsService = StatsService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var attService = ATTService.shared
    @StateObject private var consentManager = ConsentManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Prepare haptic feedback generators
        HapticManager.shared.prepareAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                hasSeenOnboarding: $hasSeenOnboarding,
                attService: attService,
                consentManager: consentManager,
                delegate: delegate
            )
            .environmentObject(themeService)
            .environmentObject(statsService)
            .environmentObject(subscriptionService)
            .environmentObject(consentManager)
            .preferredColorScheme(themeService.colorScheme)
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { @MainActor in
                        attService.refreshStatus()
                    }
                }
            }
        }
    }
}

/// Root view that handles the app flow: Onboarding -> Main
/// Launch sequence: Onboarding completes -> UMP consent -> Pre-ATT primer -> ATT -> initialize tracking SDKs
struct RootView: View {
    @Binding var hasSeenOnboarding: Bool
    @ObservedObject var attService: ATTService
    @ObservedObject var consentManager: ConsentManager
    let delegate: AppDelegate

    @AppStorage("octordle_hasShownATTPrePrompt") private var hasShownATTPrePrompt = false
    @State private var showATTPrePrompt = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else {
                ZStack {
                    MainTabView()
                        .task {
                            await startConsentAndTrackingFlow()
                        }

                    if showATTPrePrompt {
                        ATTPrePromptView(onContinue: {
                            hasShownATTPrePrompt = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showATTPrePrompt = false
                            }
                            // Let the overlay finish fading before the system ATT dialog appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                Task { @MainActor in
                                    await runATTRequest()
                                }
                            }
                        })
                        .transition(.opacity)
                        .zIndex(1)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showATTPrePrompt)
            }
        }
    }

    /// UMP consent -> Pre-ATT primer -> ATT -> initialize tracking SDKs
    /// Runs when MainTabView first appears (i.e. after onboarding completes or on returning users)
    private func startConsentAndTrackingFlow() async {
        // Step 1: UMP consent flow (GDPR/CCPA)
        await consentManager.requestConsentUpdate()

        // Step 2: ATT already handled in a prior session — skip primer, just init SDKs
        if attService.hasCompletedATTFlow {
            delegate.initializeTrackingSDKs()
            return
        }

        // Step 3: First-time ATT — show our own primer to explain why before the system dialog
        if !hasShownATTPrePrompt && ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            withAnimation(.easeInOut(duration: 0.2)) {
                showATTPrePrompt = true
            }
            return // runATTRequest() will fire from the Continue button
        }

        // Edge case: primer was shown but ATT never resolved (e.g. app killed) — go straight to ATT
        await runATTRequest()
    }

    private func runATTRequest() async {
        attService.onATTCompleted = {
            delegate.initializeTrackingSDKs()
        }
        await attService.requestTrackingPermission()
    }
}
