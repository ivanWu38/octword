import SwiftUI
import StoreKit

/// Subscription purchase view
struct SubscriptionView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""

    private let yearlyProductId = "com.octordle.premium.yearly.v1"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Personal message
                    personalMessageSection

                    // Divider
                    sectionDivider

                    // Features
                    featuresSection

                    // Divider
                    sectionDivider

                    // Products
                    productsSection

                    // Restore button
                    restoreButton

                    // Terms
                    termsSection
                }
                .padding()
            }
            .background(Color.quordleBackground.ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.quordleSecondaryText)
                    }
                }
            }
            .onAppear {
                AnalyticsService.logPaywallView()
                if selectedProduct == nil, let yearly = subscriptionService.products.last {
                    selectedProduct = yearly
                }
            }
            .onChange(of: subscriptionService.products) { products in
                if selectedProduct == nil, let yearly = products.last {
                    selectedProduct = yearly
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.quordleCardBorder.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.quordleGold)

            Text("Premium")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
        }
        .padding(.top, 20)
    }

    // MARK: - Personal Message Section

    private var personalMessageSection: some View {
        VStack(spacing: 12) {
            Text("Built by a solo developer.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.quordlePrimaryText)

            Text("You'll never see pop-up ads here — just a small banner. You don't have to subscribe — the game is fully playable without it. But if you do, every subscription directly helps make Octordle better.")
                .font(.system(size: 15))
                .foregroundColor(.quordleSecondaryText)
                .lineSpacing(4)

            Text("Either way, thanks for playing.")
                .font(.system(size: 14).italic())
                .foregroundColor(.quordleSecondaryText.opacity(0.7))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(
                icon: "paintpalette.fill",
                iconColor: Color(red: 0.61, green: 0.42, blue: 0.94),
                title: "All Themes",
                description: "Ocean, Forest, Sunset and more"
            )

            featureDivider

            FeatureRow(
                icon: "xmark.circle.fill",
                iconColor: Color(red: 0.28, green: 0.75, blue: 0.57),
                title: "No Ads",
                description: "Enjoy an ad-free experience"
            )

            featureDivider

            FeatureRow(
                icon: "star.fill",
                iconColor: .quordleGold,
                title: "Support Development",
                description: "Help us make Octordle better"
            )
        }
    }

    private var featureDivider: some View {
        Rectangle()
            .fill(Color.quordleCardBorder.opacity(0.3))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    // MARK: - Products Section

    private var productsSection: some View {
        VStack(spacing: 10) {
            if subscriptionService.isLoading {
                ProgressView()
                    .padding()
            } else if subscriptionService.products.isEmpty {
                Text("Products unavailable")
                    .foregroundColor(.quordleSecondaryText)
                    .padding()
            } else {
                let monthlyPrice = subscriptionService.products.first(where: { $0.id.contains("monthly") })?.price
                ForEach(subscriptionService.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isYearly: product.id == yearlyProductId,
                        monthlyPrice: monthlyPrice
                    ) {
                        selectedProduct = product
                        HapticManager.shared.selection()
                        AnalyticsService.logPlanSelected(productId: product.id)
                    }
                }

                if let product = selectedProduct {
                    Button {
                        Task {
                            await purchase(product)
                        }
                    } label: {
                        if subscriptionService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.1, green: 0.1, blue: 0.18)))
                        } else {
                            Text("Subscribe")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.96, green: 0.65, blue: 0.14), Color(red: 0.97, green: 0.79, blue: 0.28)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(1.0)
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(subscriptionService.isLoading)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            AnalyticsService.logRestoreTap()
            Task {
                await subscriptionService.restore()
                if subscriptionService.isPremium {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14))
                .foregroundColor(.quordleSecondaryText)
                .underline()
        }
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
            .font(.system(size: 13))
            .foregroundColor(.quordleSecondaryText)
            .multilineTextAlignment(.center)
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        AnalyticsService.logPurchaseTap(productId: product.id)
        do {
            let success = try await subscriptionService.purchase(product)
            if success {
                AnalyticsService.logPurchaseSuccess(productId: product.id)
                HapticManager.shared.success()
                dismiss()
            }
        } catch {
            AnalyticsService.logPurchaseFail(productId: product.id, error: error.localizedDescription)
            errorMessage = error.localizedDescription
            showError = true
            HapticManager.shared.error()
        }
    }
}

/// Feature row
struct FeatureRow: View {
    let icon: String
    var iconColor: Color = .quordleGold
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.quordlePrimaryText)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.quordleSecondaryText)
            }

            Spacer()
        }
        .padding(.vertical, 14)
    }
}

/// Product card
struct ProductCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let product: Product
    let isSelected: Bool
    var isYearly: Bool = false
    var monthlyPrice: Decimal?
    let onSelect: () -> Void

    private var priceColor: Color {
        colorScheme == .dark ? .quordleGold : Color(red: 0.72, green: 0.49, blue: 0.0)
    }

    private var periodUnit: String {
        if product.id.contains("monthly") { return "/ month" }
        if product.id.contains("quarterly") { return "/ quarter" }
        if product.id.contains("yearly") { return "/ year" }
        return ""
    }

    private var dynamicDescription: String {
        if product.id.contains("yearly") {
            let perMonth = NSDecimalNumber(decimal: product.price / 12).doubleValue
            return "Less than $\(String(format: "%.2f", perMonth))/month"
        } else if product.id.contains("quarterly"), let monthly = monthlyPrice {
            let quarterlyPerMonth = product.price / 3
            let savings = (1 - quarterlyPerMonth / monthly) * 100
            let percent = NSDecimalNumber(decimal: savings).intValue
            if percent > 0 {
                return "\(product.description) - Save \(percent)%"
            }
        }
        return product.description
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.quordlePrimaryText)

                        if isYearly {
                            Text("Best Value")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundColor(priceColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(priceColor.opacity(0.15))
                                )
                        }
                    }

                    Text(dynamicDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(priceColor)

                    Text(periodUnit)
                        .font(.system(size: 11))
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.quordleGold.opacity(0.08) : Color.quordleBackgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.quordleGold : Color.quordleTileBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionService.shared)
}
