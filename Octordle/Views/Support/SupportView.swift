import SwiftUI

// MARK: - Shared coffee-tinted card background

private extension View {
    /// Editorial card with a faint coffee tint — used for every support surface.
    func coffeeCard(cornerRadius: CGFloat = 14) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.quordleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.quordleCoffee.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.quordleCoffee.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

// MARK: - A · Soft support card (on today's completed screen)

/// Inline invitation shown once per day on the Daily "completed" screen,
/// after a player has a few editions under their belt. Editorial: a small
/// uppercase kicker + hairline rule above the header, matching the masthead.
struct SupportCard: View {
    let onSupport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("A Note from the Maker")
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
            }

            HStack(spacing: 10) {
                Text("☕").font(.system(size: 22))
                Text("Enjoying Octordle?")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                Spacer()
            }

            Text("It's free, and it stays free — no catch. If you ever feel like saying thanks, you can watch a short ad. Either way, I'm just happy you're here 💛")
                .font(.system(size: 13.5, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                HapticManager.shared.buttonTap()
                onSupport()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Buy me a coffee")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.quordleCoffee))
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                HapticManager.shared.buttonTap()
                onDismiss()
            } label: {
                Text("Maybe another day")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.quordleSecondaryText.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .coffeeCard()
        .padding(.horizontal, 24)
    }
}

// MARK: - C · Supporter page (the full-screen sheet, opened via the masthead coffee pill)

/// Owns the whole coffee flow when opened from the masthead pill: shows the
/// invitation (or gratitude ledger), presents the confirm sheet, runs the ad,
/// then celebrates with `CoffeeThanksOverlay`.
struct SupporterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var support = SupportService.shared
    @State private var isWorking = false
    @State private var showThanks = false

    private var hasSupported: Bool { support.coffeeCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            EditorialMasthead(
                kicker: "A Note from the Maker",
                title: "Coffee",
                subtitle: hasSupported ? "Certified Supporter" : "Support the solo dev",
                onBack: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if hasSupported { afterContent } else { beforeContent }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .iPadReadableWidth()
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { support.preload() }
        .overlay {
            if showThanks {
                CoffeeThanksOverlay(count: support.coffeeCount) {
                    showThanks = false
                }
            }
        }
    }

    // MARK: Before (no coffees yet) — the invitation

    private var beforeContent: some View {
        VStack(spacing: 0) {
            Text("☕")
                .font(.system(size: 52))
                .padding(.top, 12)

            Text("The game's free.\nMy coffee isn't.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.quordleCoffee)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 14)

            Text("Made by one human and a worrying amount of caffeine.")
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            reasonsPanel(
                header: "Where Your Coffee Goes",
                punch: "No studio. No servers.\nJust me and an empty mug."
            )
            .padding(.top, 20)
        }
    }

    // MARK: After (1+ coffees) — gratitude + ledger

    private var afterContent: some View {
        VStack(spacing: 0) {
            Text("☕")
                .font(.system(size: 46))
                .padding(.top, 10)

            Text("You caffeinated a solo developer.")
                .font(.system(size: 23, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("Legend.")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .italic()
                .foregroundColor(.quordleCoffee)
                .padding(.top, 2)

            countText
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: 12))
                Text("Certified Supporter")
                    .font(.system(size: 13, weight: .bold, design: .serif))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.quordleCoffee))
            .padding(.top, 12)

            reasonsPanel(
                header: "What You've Been Fueling",
                punch: "Seriously — thank you. It keeps me going."
            )
            .padding(.top, 18)
        }
    }

    private var countText: Text {
        let n = support.coffeeCount
        let word = n == 1 ? "coffee" : "coffees"
        return Text("That's ")
            + Text("\(n) \(word)").fontWeight(.bold).foregroundColor(.quordlePrimaryText)
            + Text(" from you so far 💛")
    }

    // MARK: Shared reasons panel (3 bullets + punch)

    private func reasonsPanel(header: String, punch: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(header)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(.quordleCoffee)

            reasonRow("📵", hasSupported
                ? "Me saying no to those full-screen ads that ruin every other game."
                : "Keeps me saying no to those full-screen ads that ruin every other game.")
            reasonRow("💛", hasSupported
                ? "The reminder that a real person out there actually plays this thing."
                : "And reminds me a real person out there actually plays this thing.")
            reasonRow("☕", hasSupported
                ? "A solo-dev life that's a little less lonely — and a lot more caffeinated."
                : "Makes the solo-dev life a little less lonely — and a lot more caffeinated.")

            Text(punch)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(.quordleCoffee)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .coffeeCard(cornerRadius: 16)
    }

    private func reasonRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon).font(.system(size: 19)).frame(width: 26)
            Text(text)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.quordlePrimaryText.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: Pinned footer (CTA stays reachable without scrolling)

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)

            Button {
                HapticManager.shared.buttonTap()
                buyCoffee()
            } label: {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("☕").font(.system(size: 16))
                    }
                    Text(hasSupported ? "Buy another" : "Buy me a coffee")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    Text("· watch a short ad")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(.white.opacity(0.82))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.quordleCoffee))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isWorking)
            .padding(.top, 8)

            Text("100% optional · the game never changes")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.quordleSecondaryText.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .background(Color.quordleBackground.ignoresSafeArea(edges: .bottom))
    }

    private func buyCoffee() {
        guard !isWorking else { return }
        isWorking = true
        Task {
            let earned = await support.buyCoffee()
            isWorking = false
            if earned {
                HapticManager.shared.gameWon()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showThanks = true
                }
            }
        }
    }
}

// MARK: - D · Thank-you overlay (after earning a coffee)

/// Celebratory overlay shown after a successful ad — from either the inline
/// card flow or the full supporter page. Stays up until the player closes it
/// (Close button or tapping the backdrop).
struct CoffeeThanksOverlay: View {
    let count: Int
    let onDone: () -> Void

    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { onDone() }

            VStack(spacing: 14) {
                Text("☕")
                    .font(.system(size: 60))
                    .scaleEffect(pop ? 1.0 : 0.4)

                Text("Thank you! 🙏")
                    .font(.system(size: 21, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)

                Text("+1 coffee · \(count) total")
                    .font(.system(size: 13.5, weight: .bold, design: .serif))
                    .foregroundColor(.quordleCoffee)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.quordleCoffee.opacity(0.14)))

                Text("You just bought me a coffee. It genuinely helps keep the daily puzzles coming.")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)

                Button {
                    HapticManager.shared.buttonTap()
                    onDone()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.quordleCardBorder, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 26)
                .padding(.top, 6)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.quordleCardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.quordleCardBorder, lineWidth: 1))
            )
            .padding(40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { pop = true }
        }
    }
}

#Preview {
    SupporterView()
}
