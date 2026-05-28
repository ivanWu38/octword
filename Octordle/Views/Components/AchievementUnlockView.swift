import SwiftUI

/// In-game card shown when an achievement is unlocked — editorial "Daily Edition"
/// styling, matching AchievementDetailView. Presented over the game screen the
/// same way ThemeUnlockView is, after the result sheet is dismissed.
struct AchievementUnlockView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                // Framed icon (newspaper engraving style)
                ZStack {
                    Rectangle().fill(Color.quordleCardBackground)
                    Rectangle().stroke(Color.quordlePrimaryText, lineWidth: 1.5)
                    Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1).padding(5)
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 34))
                        .foregroundColor(.quordlePrimary)
                }
                .frame(width: 88, height: 88)
                .scaleEffect(iconScale)

                VStack(spacing: 6) {
                    Text("Achievement Unlocked")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(.quordlePrimary)

                    Text(achievement.title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.quordleSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button { dismiss() } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 2)
            }
            .padding(28)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.quordleBackground)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.quordleCardBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 28, y: 14)
            )
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            HapticManager.shared.achievementUnlocked()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) { iconScale = 1.0 }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
    }
}
