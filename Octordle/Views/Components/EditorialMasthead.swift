import SwiftUI

/// The shared "Daily Edition" nameplate used on every page. Fixed structure so
/// headers stay identical screen to screen: kicker → top rule → title band →
/// bottom rule → subtitle. The band hosts optional flanking controls, vertically
/// centered between the two rules — a coffee pill or back chevron on the left, a
/// settings gear on the right. The title is pinned to one line and auto-shrinks,
/// so nothing wraps awkwardly on narrow devices.
struct EditorialMasthead: View {
    let kicker: String
    let title: String
    let subtitle: String

    /// Left slot: a back chevron takes priority; otherwise a coffee pill if enabled.
    var onBack: (() -> Void)? = nil
    var showCoffee: Bool = false
    var coffeeCount: Int = 0
    var onCoffee: (() -> Void)? = nil

    /// Right slot: the settings gear (root pages only).
    var onSettings: (() -> Void)? = nil

    private let slotWidth: CGFloat = 46
    private let bandHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            microLine(kicker)

            rule

            HStack(spacing: 4) {
                leftSlot
                    .frame(width: slotWidth, alignment: .leading)

                Text(title)
                    .font(.system(size: 33, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)

                rightSlot
                    .frame(width: slotWidth, alignment: .trailing)
            }
            .frame(height: bandHeight)

            rule

            microLine(subtitle)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var rule: some View {
        Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
    }

    private func microLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(.quordleSecondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    // MARK: - Slots

    @ViewBuilder private var leftSlot: some View {
        if let onBack {
            Button {
                HapticManager.shared.backTap()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.quordlePrimaryText)
                    .frame(width: slotWidth, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.9))
        } else if showCoffee {
            Button {
                HapticManager.shared.buttonTap()
                onCoffee?()
            } label: {
                HStack(spacing: 3) {
                    Text("☕").font(.system(size: 12))
                    Text("\(coffeeCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.quordleCoffee)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.quordleCardBackground)
                        .overlay(Capsule().stroke(Color.quordleCoffee.opacity(0.3), lineWidth: 1))
                )
                .contentShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.9))
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    @ViewBuilder private var rightSlot: some View {
        if let onSettings {
            Button {
                HapticManager.shared.buttonTap()
                onSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(.quordleSecondaryText)
                    .frame(width: slotWidth, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.9))
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        EditorialMasthead(kicker: "Beyond the Daily", title: "Explore",
                          subtitle: "Categories · Challenges",
                          showCoffee: true, coffeeCount: 3, onCoffee: {}, onSettings: {})
        EditorialMasthead(kicker: "Themed Word Packs", title: "Categories",
                          subtitle: "12 of 306 solved", onBack: {})
    }
    .background(Color.quordleBackground)
}
