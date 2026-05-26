import Foundation
import UserMessagingPlatform

/// Google UMP (User Messaging Platform) consent manager
/// Handles GDPR/CCPA consent flow before ads can be served
@MainActor
class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published private(set) var canRequestAds: Bool = false
    @Published private(set) var isConsentFormAvailable: Bool = false

    private init() {
        // Check initial consent status
        canRequestAds = UMPConsentInformation.sharedInstance.canRequestAds
    }

    // MARK: - Consent Flow

    /// Request consent info update and show form if needed
    /// Call this at app launch before requesting ATT or loading ads
    func requestConsentUpdate() async {
        let parameters = UMPRequestParameters()

        #if DEBUG
        let debugSettings = UMPDebugSettings()
        debugSettings.testDeviceIdentifiers = ["01da80481aa6bbecc0503354423e83c2"]
        parameters.debugSettings = debugSettings
        #endif

        // Request updated consent information
        do {
            try await UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters)
            isConsentFormAvailable = UMPConsentInformation.sharedInstance.formStatus == .available
            print("[UMP] Consent info updated. Status: \(statusDescription)")
        } catch {
            print("[UMP] Failed to update consent info: \(error.localizedDescription)")
        }

        // Load and present the consent form if required
        do {
            try await UMPConsentForm.loadAndPresentIfRequired(from: nil)
            print("[UMP] Consent form handled. canRequestAds: \(UMPConsentInformation.sharedInstance.canRequestAds)")
        } catch {
            print("[UMP] Consent form error: \(error.localizedDescription)")
        }

        // Update published state
        canRequestAds = UMPConsentInformation.sharedInstance.canRequestAds
    }

    // MARK: - Privacy Options (Revoke Consent)

    /// Whether the privacy options form is available (for settings page)
    var isPrivacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    /// Present the privacy options form so the user can change their consent
    func presentPrivacyOptionsForm() async {
        do {
            try await UMPConsentForm.presentPrivacyOptionsForm(from: nil)
            // Update state after user changes consent
            canRequestAds = UMPConsentInformation.sharedInstance.canRequestAds
            print("[UMP] Privacy options updated. canRequestAds: \(canRequestAds)")
        } catch {
            print("[UMP] Privacy options form error: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset (Testing Only)

    #if DEBUG
    /// Reset consent state for testing
    func reset() {
        UMPConsentInformation.sharedInstance.reset()
        canRequestAds = false
        isConsentFormAvailable = false
        print("[UMP] Consent state reset")
    }
    #endif

    // MARK: - Helpers

    private var statusDescription: String {
        switch UMPConsentInformation.sharedInstance.consentStatus {
        case .unknown: return "unknown"
        case .notRequired: return "notRequired"
        case .required: return "required"
        case .obtained: return "obtained"
        @unknown default: return "unrecognized"
        }
    }
}
