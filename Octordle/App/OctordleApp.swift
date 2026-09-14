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
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
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

        // Warm up the rewarded ads (archive puzzles + themed-category levels) so
        // they're ready the moment the player needs one.
        RewardedAdManager.shared.preloadIfNeeded()
        RewardedAdManager.category.preloadIfNeeded()
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

    /// True when launched with OCTORDLE_STREAK_TEST (DEBUG only): skips onboarding.
    private var isStreakHarness: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["OCTORDLE_STREAK_TEST"] != nil || env["OCTORDLE_AD_DIAG"] == "1"
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if !hasSeenOnboarding && !isStreakHarness {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else {
                ZStack {
                    MainTabView()
                        .task {
                            #if DEBUG
                            // Streak-rescue harness: OCTORDLE_STREAK_TEST=gap1|gap2|short|cooldown|done|nextup|nextupfree
                            if let scenario = ProcessInfo.processInfo.environment["OCTORDLE_STREAK_TEST"] {
                                DailyPuzzleService.shared.debugSeedStreak(scenario)
                                delegate.initializeTrackingSDKs() // ads without consent/ATT dialogs
                                return
                            }
                            // Mediation diagnostics harness: OCTORDLE_AD_DIAG=1 (+ OCTORDLE_PROD_ADS=1) — straight to SDK start.
                            if ProcessInfo.processInfo.environment["OCTORDLE_AD_DIAG"] == "1" {
                                delegate.initializeTrackingSDKs()
                                return
                            }
                            // Review-prompt harness: OCTORDLE_REVIEW_TEST=reset clears state and asks at
                            // launch; OCTORDLE_REVIEW_TEST=ask just re-asks (to verify cooldowns).
                            if let mode = ProcessInfo.processInfo.environment["OCTORDLE_REVIEW_TEST"] {
                                let r = ReviewManager.shared
                                if mode == "reset" { r.resetAll() }
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                r.considerPrompt(triggers: [.perfectWin])
                                print("[ReviewTest] considerPrompt -> \(r.isPromptShowing) lastPrompt=\(String(describing: r.lastPromptDate)) consecutive=\(r.consecutivePromptCount) ratedVersion=\(String(describing: r.lastRatedVersion))")
                                return
                            }
                            #endif
                            await startConsentAndTrackingFlow()
                        }
                        .reviewPromptHarness()

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

#if DEBUG
/// Harness-only presenter (in real play GameView presents the sheet).
private struct ReviewPromptHarness: ViewModifier {
    @ObservedObject private var review = ReviewManager.shared
    @Environment(\.openURL) private var openURL
    @State private var choice: Int? // 1 rate, 2 later
    func body(content: Content) -> some View {
        content.sheet(isPresented: $review.isPromptShowing, onDismiss: {
            switch choice {
            case 1: openURL(ReviewManager.writeReviewURL)
            case 2: break
            default: review.userDismissedWithoutChoice()
            }
            choice = nil
        }) {
            ReviewPromptView(onAccept: { choice = 1; review.userAccepted() },
                             onDecline: { choice = 2; review.userDeclined() })
                .interactiveDismissDisabled()
        }
    }
}
private extension View {
    @ViewBuilder
    func reviewPromptHarness() -> some View {
        if ProcessInfo.processInfo.environment["OCTORDLE_REVIEW_TEST"] != nil { self.modifier(ReviewPromptHarness()) } else { self }
    }
}
#else
private extension View {
    func reviewPromptHarness() -> some View { self }
}
#endif
