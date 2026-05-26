import AppTrackingTransparency
import AdSupport
import SwiftUI
import UIKit

/// App Tracking Transparency service
/// Handles ATT flow reliably on iPhone and iPad (including iPadOS 26+)
@MainActor
class ATTService: ObservableObject {
    static let shared = ATTService()

    private let defaults = UserDefaults.standard
    private let hasCompletedATTFlowKey = "octordle_hasCompletedATTFlow"

    @Published private(set) var authorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published private(set) var hasCompletedATTFlow: Bool
    @Published private(set) var isRequestingPermission = false

    /// Callback invoked once when ATT flow completes (authorized or not)
    var onATTCompleted: (() -> Void)?

    private init() {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        let storedCompleted = defaults.bool(forKey: hasCompletedATTFlowKey)

        authorizationStatus = currentStatus

        // If ATT status is already determined (not .notDetermined), auto-complete the flow
        if currentStatus != .notDetermined {
            hasCompletedATTFlow = true
            if !storedCompleted {
                defaults.set(true, forKey: hasCompletedATTFlowKey)
            }
        } else {
            hasCompletedATTFlow = storedCompleted
        }
    }

    /// Request tracking permission via system ATT dialog
    /// Uses NotificationCenter to reliably detect when the app is truly active
    func requestTrackingPermission() async {
        // Prevent concurrent requests
        guard !isRequestingPermission else { return }

        // If already determined, just notify and return
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        if currentStatus != .notDetermined {
            authorizationStatus = currentStatus
            if !hasCompletedATTFlow {
                markFlowCompleted()
            }
            return
        }

        isRequestingPermission = true

        // Wait until app is truly active and UI is ready
        await waitForSceneReady()

        // Request system permission
        let status = await ATTrackingManager.requestTrackingAuthorization()
        authorizationStatus = status

        // Mark flow as completed
        markFlowCompleted()
        isRequestingPermission = false
    }

    /// Wait for the app scene to be fully active — critical for iPad
    /// Uses UIScene.didActivateNotification for reliable detection
    private func waitForSceneReady() async {
        // First check if already active
        if isSceneActive() {
            // Small delay for UI stability after scene activation
            try? await Task.sleep(nanoseconds: 500_000_000)
            return
        }

        // Wait for scene activation notification (with safety timeout)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var hasResumed = false
            var observer: NSObjectProtocol?

            let resume = {
                guard !hasResumed else { return }
                hasResumed = true
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                }
                continuation.resume()
            }

            observer = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { _ in
                resume()
            }

            // Safety timeout in case scene is already active but we missed it
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                resume()
            }
        }

        // Additional delay after scene activation for UI to fully stabilize on iPad
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    /// Check if any connected scene is in foreground active state
    private func isSceneActive() -> Bool {
        return UIApplication.shared.connectedScenes.contains { scene in
            scene.activationState == .foregroundActive
        }
    }

    /// Mark ATT flow as completed and notify listeners
    private func markFlowCompleted() {
        hasCompletedATTFlow = true
        defaults.set(true, forKey: hasCompletedATTFlowKey)
        onATTCompleted?()
        onATTCompleted = nil
    }

    /// Check if tracking is authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// Check if tracking is restricted (parental controls)
    var isRestricted: Bool {
        authorizationStatus == .restricted
    }

    /// Get IDFA if authorized
    var idfa: String? {
        guard isAuthorized else { return nil }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return idfa == "00000000-0000-0000-0000-000000000000" ? nil : idfa
    }

    /// Reset ATT flow (for testing)
    func resetATTFlow() {
        defaults.removeObject(forKey: hasCompletedATTFlowKey)
        hasCompletedATTFlow = false
        isRequestingPermission = false
        authorizationStatus = ATTrackingManager.trackingAuthorizationStatus
    }

    /// Refresh authorization status (call when app becomes active)
    func refreshStatus() {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        if currentStatus != authorizationStatus {
            authorizationStatus = currentStatus
            if currentStatus != .notDetermined && !hasCompletedATTFlow {
                markFlowCompleted()
            }
        }
    }
}
