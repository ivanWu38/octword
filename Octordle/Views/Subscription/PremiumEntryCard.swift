import SwiftUI

/// Always-on Premium entry card for high-traffic pages (Explore / Unlimited).
/// Quietly persistent — no animation, no dismiss button. Hidden for premium users.
/// Opens the paywall as a sheet and reports the entry source to analytics.
///
/// Styled as a house advertisement in the paper: a small-caps rule band on top
/// (which carries a live status line), then a gold-framed mark and serif title.
struct PremiumEntryCard: View {
    /// Analytics source and copy variant: "explore" or "unlimited".
    let source: String

    @EnvironmentObject var subscriptionService: SubscriptionService
    @ObservedObject private var categoryService = CategoryService.shared
    @State private var showPaywall = false

    private var isUnlimited: Bool { source == "unlimited" }

    private var subtitle: String {
        isUnlimited
            ? "Play ad-free · unlock everything"
            : "All \(categoryService.categories.count) packs · full archive · no ads"
    }

    /// Right side of the rule band — a live fact on Explore, a plain promise elsewhere.
    private var bandStatus: String {
        guard !isUnlimited else { return "Ad-free" }
        let locked = categoryService.categories.filter { !$0.free }.count
        return locked > 0 ? "\(locked) packs locked" : "Full archive"
    }

    var body: some View {
        if !subscriptionService.isPremium {
            Button {
                HapticManager.shared.cardTap()
                showPaywall = true
            } label: {
                VStack(spacing: 0) {
                    HStack {
                        Text("Subscriber's Edition")
                            .font(.system(size: 8.5, weight: .bold))
                            .tracking(2.2)
                            .textCase(.uppercase)
                            .foregroundColor(.quordleSecondary)
                        Spacer(minLength: 8)
                        Text(bandStatus)
                            .font(.system(size: 8.5, weight: .medium))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundColor(.quordleSecondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.quordlePrimary.opacity(0.35)).frame(height: 1)
                    }

                    HStack(spacing: 12) {
                        Text("❦")
                            .font(.system(size: 19))
                            .foregroundColor(.quordleGold)
                            .frame(width: 40, height: 40)
                            .background(Rectangle().fill(Color.quordleGold.opacity(0.10)))
                            .overlay(Rectangle().stroke(Color.quordleGold, lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Octors Premium")
                                .font(.system(size: 16.5, weight: .bold, design: .serif))
                                .foregroundColor(.quordlePrimaryText)
                            Text(subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(.quordleSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.quordlePrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.quordlePrimary.opacity(0.055),
                                     Color.quordleGold.opacity(0.06)],
                            startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.quordlePrimary, lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.97))
            .sheet(isPresented: $showPaywall) {
                SubscriptionView(source: source)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PremiumEntryCard(source: "explore")
        PremiumEntryCard(source: "unlimited")
    }
    .padding(20)
    .background(Color.quordleBackground)
    .environmentObject(SubscriptionService.shared)
}
