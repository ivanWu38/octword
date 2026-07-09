import SwiftUI

/// Bottom sheet shown when a player taps a locked Premium pack (from the pack
/// list) or a locked level inside one. Editorial "Daily Edition" styling.
/// Two paths: watch a rewarded ad to unlock a single level, or go Premium to
/// unlock everything. Each ad unlocks exactly one level.
struct LockedPackSheet: View {
    let category: WordCategory
    /// Total number of packs, for the Premium subtitle ("All N packs …").
    let packCount: Int
    let onWatchAd: () -> Void
    let onPremium: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var wordCount: Int {
        category.puzzles.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Premium Pack")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            rule.padding(.top, 8)

            HStack(spacing: 9) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.quordleCoffee)
                Text(category.name)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            rule

            Text("\(category.puzzleCount) puzzles · \(wordCount) words on one theme")
                .font(.system(size: 13))
                .foregroundColor(.quordleSecondaryText)
                .padding(.top, 10)

            // Primary — watch a rewarded ad (gold)
            optionButton(action: onWatchAd) {
                optionRow(
                    icon: Image(systemName: "play.fill"),
                    iconBackground: Color.white.opacity(0.22),
                    iconForeground: .white,
                    title: "Watch a short ad",
                    subtitle: "Unlock one level and start playing",
                    titleColor: .white,
                    subtitleColor: .white.opacity(0.92),
                    chevronColor: .white.opacity(0.92),
                    showAdBadge: true
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [Color.quordleGold.opacity(0.92), .quordleGold],
                            startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quordleGold, lineWidth: 1))
                )
            }
            .padding(.top, 14)

            // Secondary — go Premium (outline)
            optionButton(action: onPremium) {
                optionRow(
                    icon: Image(systemName: "star.fill"),
                    iconBackground: Color.quordleCardBackground,
                    iconForeground: .quordleGold,
                    iconBordered: true,
                    title: "Unlock every pack with Premium",
                    subtitle: "All \(packCount) packs, forever · no ads",
                    titleColor: .quordlePrimaryText,
                    subtitleColor: .quordleSecondaryText,
                    chevronColor: .quordleSecondaryText,
                    showAdBadge: false
                )
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.quordleCardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quordleCardBorder, lineWidth: 1))
                )
            }
            .padding(.top, 12)

            Text("Each ad unlocks one level — or go ad-free forever with Premium.")
                .font(.system(size: 11.5))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Button {
                HapticManager.shared.buttonTap()
                dismiss()
            } label: {
                Text("Not now")
                    .font(.system(size: 14, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
    }

    private var rule: some View {
        Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
    }

    private func optionButton<Content: View>(action: @escaping () -> Void,
                                             @ViewBuilder content: () -> Content) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            content()
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }

    private func optionRow(icon: Image,
                           iconBackground: Color,
                           iconForeground: Color,
                           iconBordered: Bool = false,
                           title: String,
                           subtitle: String,
                           titleColor: Color,
                           subtitleColor: Color,
                           chevronColor: Color,
                           showAdBadge: Bool) -> some View {
        HStack(spacing: 13) {
            icon
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(iconForeground)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(iconBordered ? Color.quordleCardBorder : Color.clear, lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16.5, weight: .bold, design: .serif))
                        .foregroundColor(titleColor)
                        .fixedSize(horizontal: false, vertical: true)
                    if showAdBadge {
                        Text("AD")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.black.opacity(0.18)))
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(subtitleColor)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(chevronColor)
        }
        .padding(15)
    }
}
