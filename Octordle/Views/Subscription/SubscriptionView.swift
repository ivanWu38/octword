import SwiftUI
import StoreKit

/// Subscription purchase view — "A Subscriber's Edition".
struct SubscriptionView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""

    private let yearlyProductId = "com.oct.premium.yearly.v1"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    personalMessageSection
                    sectionDivider
                    featuresSection
                    sectionDivider
                    productsSection
                    restoreButton
                    termsSection
                }
                .padding()
                .iPadReadableWidth(520)
            }
            .background(Color.quordleBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
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

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle().fill(Color.quordleCardBorder).frame(height: 1).padding(.horizontal, 2)
    }

    // MARK: - Header (masthead)

    private var headerSection: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
            Text("Octordle Premium")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .padding(.vertical, 8)
            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
            Text("A Subscriber's Edition")
                .font(.system(size: 10.5, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .padding(.top, 8)
        }
        .padding(.top, 10)
    }

    // MARK: - Personal Message (preserved copy)

    private var personalMessageSection: some View {
        VStack(spacing: 12) {
            Text("Built by a solo developer.")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundColor(.quordlePrimaryText)

            Text("You'll never see pop-up ads here — just a small banner. You don't have to subscribe — the game is fully playable without it. But if you do, every subscription directly helps make Octordle better.")
                .font(.system(size: 15, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .lineSpacing(4)

            Text("Either way, thanks for playing.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(.quordleSecondaryText.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(symbol: "❦", title: "Every Theme Unlocked", description: "Dress the page your way.")
            featureDivider
            FeatureRow(symbol: "⊘", title: "No Advertisements", description: "A clean, quiet page.")
            featureDivider
            FeatureRow(symbol: "✶", title: "Support the Press", description: "Made by one person.")
        }
    }

    private var featureDivider: some View {
        Rectangle().fill(Color.quordleCardBorder).frame(height: 1).padding(.leading, 60)
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: 10) {
            if subscriptionService.isLoading {
                ProgressView().padding()
            } else if subscriptionService.products.isEmpty {
                Text("Products unavailable").foregroundColor(.quordleSecondaryText).padding()
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
                        Task { await purchase(product) }
                    } label: {
                        Group {
                            if subscriptionService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Subscribe")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(subscriptionService.isLoading)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            AnalyticsService.logRestoreTap()
            Task {
                await subscriptionService.restore()
                if subscriptionService.isPremium { dismiss() }
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .underline()
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings. Payment is charged to your Apple ID account at confirmation of purchase.")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: "https://ikuheikure.xyz/apps/octordle-word-puzzle/")!)
            }
            .font(.system(size: 12, design: .serif))
            .foregroundColor(.quordlePrimary)
        }
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
            // Log the real underlying error for diagnostics, but never surface a
            // raw StoreKit string (e.g. "Item Unavailable") to the user — show a
            // calm, actionable message instead.
            AnalyticsService.logPurchaseFail(productId: product.id, error: error.localizedDescription)
            errorMessage = "Purchases are temporarily unavailable. Please try again later."
            showError = true
            HapticManager.shared.error()
        }
    }
}

/// Feature row — framed mark + serif text.
struct FeatureRow: View {
    let symbol: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text(symbol)
                .font(.system(size: 18))
                .foregroundColor(.quordlePrimary)
                .frame(width: 44, height: 44)
                .overlay(Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                Text(description)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(.quordleSecondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 13)
    }
}

/// Product card — editorial row, terracotta selection.
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    var isYearly: Bool = false
    var monthlyPrice: Decimal?
    let onSelect: () -> Void

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
            if percent > 0 { return "\(product.description) - Save \(percent)%" }
        }
        return product.description
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(.quordlePrimaryText)
                        if isYearly {
                            Text("Best Value")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundColor(.quordlePrimary)
                        }
                    }
                    Text(dynamicDescription)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(periodUnit)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.quordleCardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.quordlePrimary : Color.quordleCardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionService.shared)
}
