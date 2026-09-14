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
        canRequestAds = ConsentInformation.shared.canRequestAds
    }

    // MARK: - Consent Flow

    /// Request consent info update and show form if needed
    /// Call this at app launch before requesting ATT or loading ads
    func requestConsentUpdate() async {
        let parameters = RequestParameters()

        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.testDeviceIdentifiers = ["01da80481aa6bbecc0503354423e83c2"]
        parameters.debugSettings = debugSettings
        #endif

        // Request updated consent information
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            isConsentFormAvailable = ConsentInformation.shared.formStatus == .available
            print("[UMP] Consent info updated. Status: \(statusDescription)")
        } catch {
            print("[UMP] Failed to update consent info: \(error.localizedDescription)")
        }

        // Load and present the consent form if required
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
            print("[UMP] Consent form handled. canRequestAds: \(ConsentInformation.shared.canRequestAds)")
        } catch {
            print("[UMP] Consent form error: \(error.localizedDescription)")
        }

        // Update published state
        canRequestAds = ConsentInformation.shared.canRequestAds
    }

    // MARK: - Privacy Options (Revoke Consent)

    /// Whether the privacy options form is available (for settings page)
    var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Present the privacy options form so the user can change their consent
    func presentPrivacyOptionsForm() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            // Update state after user changes consent
            canRequestAds = ConsentInformation.shared.canRequestAds
            print("[UMP] Privacy options updated. canRequestAds: \(canRequestAds)")
        } catch {
            print("[UMP] Privacy options form error: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset (Testing Only)

    #if DEBUG
    /// Reset consent state for testing
    func reset() {
        ConsentInformation.shared.reset()
        canRequestAds = false
        isConsentFormAvailable = false
        print("[UMP] Consent state reset")
    }
    #endif

    // MARK: - Helpers

    private var statusDescription: String {
        switch ConsentInformation.shared.consentStatus {
        case .unknown: return "unknown"
        case .notRequired: return "notRequired"
        case .required: return "required"
        case .obtained: return "obtained"
        @unknown default: return "unrecognized"
        }
    }
}
