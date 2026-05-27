import SwiftUI

/// Settings view
struct SettingsView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var consentManager: ConsentManager

    @State private var showSubscription = false
    @State private var showOnboarding = false
    @State private var onboardingCompleted = false

    var body: some View {
        NavigationStack {
            List {
                // Premium section
                premiumSection

                // Appearance section
                appearanceSection

                // Sound & Haptics section
                feedbackSection

                // Support section
                supportSection

                // Privacy section (only in CMP-required regions)
                if consentManager.isPrivacyOptionsRequired {
                    privacySection
                }

                // About section
                aboutSection
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 50)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(hasSeenOnboarding: $onboardingCompleted)
            }
            .onChange(of: onboardingCompleted) { newValue in
                if newValue {
                    showOnboarding = false
                    onboardingCompleted = false  // Reset for next time
                }
            }
        }
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        Section {
            if subscriptionService.isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.quordleGold)
                    Text("Premium Active")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.quordleCorrect)
                }
            } else {
                Button {
                    HapticManager.shared.buttonTap()
                    showSubscription = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.quordleGold)
                        Text("Upgrade to Premium")
                            .foregroundColor(.quordlePrimaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.quordleSecondaryText)
                    }
                }
            }
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            // Theme picker
            NavigationLink {
                ThemePickerView()
            } label: {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.quordlePresent)
                    Text("Theme")
                    Spacer()
                    Text(themeService.selectedTheme.displayName)
                        .foregroundColor(.quordleSecondaryText)
                }
            }

            // Color scheme
            Picker(selection: $themeService.colorSchemePreference) {
                ForEach(ColorSchemePreference.allCases, id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            } label: {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple)
                    Text("Appearance")
                }
            }
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        Section {
            Toggle(isOn: $themeService.hapticEnabled) {
                HStack {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundColor(.quordleCorrect)
                    Text("Haptic Feedback")
                }
            }
            .onChange(of: themeService.hapticEnabled) { _ in
                HapticManager.shared.toggleSwitch()
            }

            Toggle(isOn: $themeService.soundEnabled) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                    Text("Sound Effects")
                }
            }
            .onChange(of: themeService.soundEnabled) { _ in
                HapticManager.shared.toggleSwitch()
            }
        } header: {
            Text("Feedback")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            // Rate on App Store
            Link(destination: URL(string: "https://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review")!) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.quordleGold)
                    Text("Rate on App Store")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }

            // Send Feedback
            Link(destination: URL(string: "mailto:wuyuping38@gmail.com?subject=Octordle%20Feedback")!) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.quordlePrimary)
                    Text("Send Feedback")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }
        } header: {
            Text("Support")
        } footer: {
            Text("We'd love to hear from you! Your feedback helps us improve.")
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            Button {
                HapticManager.shared.buttonTap()
                Task {
                    await consentManager.presentPrivacyOptionsForm()
                }
            } label: {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.orange)
                    Text("Privacy Settings")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Manage your ad personalization and data privacy preferences.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // How to Play button
            Button {
                HapticManager.shared.buttonTap()
                showOnboarding = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.quordlePrimary)
                    Text("How to Play")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }

            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundColor(.quordleSecondaryText)
            }

            Link(destination: URL(string: "https://ikuheikure.xyz/apps/q_uordle/")!) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }

            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                HStack {
                    Text("Terms of Use")
                        .foregroundColor(.quordlePrimaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.quordleSecondaryText)
                }
            }
        } header: {
            Text("About")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeService.shared)
        .environmentObject(SubscriptionService.shared)
        .environmentObject(ConsentManager.shared)
}
