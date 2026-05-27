import SwiftUI

/// Settings — editorial "Daily Edition" styling.
struct SettingsView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var consentManager: ConsentManager

    @State private var showSubscription = false
    @State private var showOnboarding = false
    @State private var onboardingCompleted = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    masthead

                    groupLabel("Subscription")
                    premiumRow

                    groupLabel("Appearance")
                    NavigationLink { ThemePickerView() } label: {
                        rowBody(symbol: "paintpalette", title: "Theme", trailingText: themeService.selectedTheme.displayName)
                    }
                    hairline
                    Menu {
                        ForEach(ColorSchemePreference.allCases, id: \.self) { pref in
                            Button(pref.displayName) { themeService.colorSchemePreference = pref }
                        }
                    } label: {
                        rowBody(symbol: "circle.lefthalf.filled", title: "Appearance",
                                trailingText: themeService.colorSchemePreference.displayName, trailingSymbol: "chevron.up.chevron.down")
                    }

                    groupLabel("Feedback")
                    toggleRow(symbol: "iphone.radiowaves.left.and.right", title: "Haptic Feedback", isOn: $themeService.hapticEnabled)
                    hairline
                    toggleRow(symbol: "speaker.wave.2", title: "Sound Effects", isOn: $themeService.soundEnabled)

                    groupLabel("Support")
                    Link(destination: URL(string: "https://apps.apple.com/app/id\(Constants.App.appStoreId)?action=write-review")!) {
                        rowBody(symbol: "star", title: "Rate on App Store", trailingSymbol: "arrow.up.right")
                    }
                    hairline
                    Link(destination: URL(string: "mailto:wuyuping38@gmail.com?subject=Octordle%20Feedback")!) {
                        rowBody(symbol: "envelope", title: "Send Feedback", trailingSymbol: "arrow.up.right")
                    }

                    if consentManager.isPrivacyOptionsRequired {
                        groupLabel("Privacy")
                        Button {
                            HapticManager.shared.buttonTap()
                            Task { await consentManager.presentPrivacyOptionsForm() }
                        } label: {
                            rowBody(symbol: "hand.raised", title: "Privacy Settings")
                        }
                    }

                    groupLabel("About")
                    Button {
                        HapticManager.shared.buttonTap()
                        showOnboarding = true
                    } label: {
                        rowBody(symbol: "questionmark.circle", title: "How to Play")
                    }
                    hairline
                    rowBody(symbol: "info.circle", title: "Version", trailingText: appVersion, trailingSymbol: nil)
                    hairline
                    Link(destination: URL(string: "https://ikuheikure.xyz/apps/octordle-word-puzzle/")!) {
                        rowBody(symbol: "doc.text", title: "Privacy Policy", trailingSymbol: "arrow.up.right")
                    }
                    hairline
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        rowBody(symbol: "doc.plaintext", title: "Terms of Use", trailingSymbol: "arrow.up.right")
                    }

                    Spacer().frame(height: 90)
                }
                .iPadReadableWidth(520)
            }
            .background(Color.quordleBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSubscription) { SubscriptionView() }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(hasSeenOnboarding: $onboardingCompleted)
            }
            .onChange(of: onboardingCompleted) { newValue in
                if newValue {
                    showOnboarding = false
                    onboardingCompleted = false
                }
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .padding(.vertical, 8)
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    // MARK: - Premium Row

    @ViewBuilder
    private var premiumRow: some View {
        if subscriptionService.isPremium {
            rowBody(symbol: "crown.fill", title: "Premium Active", trailingText: "Thank you", trailingSymbol: nil)
        } else {
            Button {
                HapticManager.shared.buttonTap()
                showSubscription = true
            } label: {
                rowBody(symbol: "crown", title: "Upgrade to Premium")
            }
        }
    }

    // MARK: - Building blocks

    private func groupLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 4)
    }

    private var hairline: some View {
        Rectangle().fill(Color.quordleCardBorder).frame(height: 1).padding(.leading, 58)
    }

    private func rowBody(symbol: String, title: String, trailingText: String? = nil, trailingSymbol: String? = "chevron.right") -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(.quordlePrimary)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 16, design: .serif))
                .foregroundColor(.quordlePrimaryText)
            Spacer()
            if let t = trailingText {
                Text(t).font(.system(size: 14, design: .serif)).foregroundColor(.quordleSecondaryText)
            }
            if let s = trailingSymbol {
                Image(systemName: s).font(.system(size: 12, weight: .semibold)).foregroundColor(.quordleSecondaryText.opacity(0.6))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func toggleRow(symbol: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(.quordlePrimary)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 16, design: .serif))
                .foregroundColor(.quordlePrimaryText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.quordlePrimary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .onChange(of: isOn.wrappedValue) { _ in HapticManager.shared.toggleSwitch() }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeService.shared)
        .environmentObject(SubscriptionService.shared)
        .environmentObject(ConsentManager.shared)
}
