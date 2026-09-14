import SwiftUI

/// Boxed editorial "NOTICE" on the Today page: the streak ended yesterday, restore
/// it with a rewarded ad (free for Premium), or "Not now" hides it for today.
struct StreakRiskNotice: View {
    let brokenStreak: Int
    let isPremium: Bool
    let isWorking: Bool
    let onRestore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your \(brokenStreak)-day streak ended yesterday.")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(isPremium
                 ? "Restore it for free with Premium. Today's edition will count as day \(brokenStreak + 1)."
                 : "Watch a short ad to restore it. Today's edition will count as day \(brokenStreak + 1).")
                .font(.system(size: 12.5, design: .serif))
                .italic()
                .foregroundColor(.quordleSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: onRestore) {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView().tint(.quordleBackgroundSecondary)
                        } else if !isPremium {
                            Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                        }
                        Text("Restore streak")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                    }
                    .foregroundColor(.quordleBackgroundSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.quordlePrimary))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isWorking)

                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.quordleCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.quordlePrimary, lineWidth: 1.5))
        )
        .overlay(alignment: .topLeading) {
            Text("NOTICE")
                .font(.system(size: 9.5, weight: .heavy))
                .tracking(2.5)
                .foregroundColor(.quordlePrimary)
                .padding(.horizontal, 6)
                .background(Color.quordleBackground)
                .offset(x: 12, y: -7)
        }
    }
}
