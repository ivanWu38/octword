import SwiftUI

/// Achievement detail popup with circular progress ring animation
struct AchievementDetailView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: (current: Int, required: Int)
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.3
    @State private var ringProgress: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200

    private var achievementColor: Color {
        switch achievement.iconColor {
        case "gold": return .quordleGold
        case "orange": return .quordleOrange
        case "blue": return .quordlePrimary
        case "purple": return .quordleSecondary
        case "green": return .quordleSuccess
        case "red": return .red
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .quordlePrimary
        }
    }

    private var progressFraction: CGFloat {
        guard progress.required > 0 else { return 0 }
        return CGFloat(progress.current) / CGFloat(progress.required)
    }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(appeared ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Icon with animated ring
                    ZStack {
                        // Outer glow for unlocked
                        if isUnlocked {
                            Circle()
                                .fill(achievementColor.opacity(0.20))
                                .frame(width: 120, height: 120)
                                .blur(radius: 25)
                        }

                        // Ring track
                        Circle()
                            .stroke(achievementColor.opacity(0.15), lineWidth: 4)
                            .frame(width: 96, height: 96)

                        // Animated progress ring
                        Circle()
                            .trim(from: 0, to: ringProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [achievementColor, achievementColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(-90))

                        // Icon background
                        Circle()
                            .fill(
                                isUnlocked
                                    ? LinearGradient(
                                        colors: [achievementColor.opacity(0.25), achievementColor.opacity(0.12)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.quordleCardBorder.opacity(0.3), Color.quordleCardBorder.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 80, height: 80)

                        // Icon
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(
                                isUnlocked
                                    ? LinearGradient(colors: [achievementColor, achievementColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.quordleSecondaryText.opacity(0.4), Color.quordleSecondaryText.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(iconScale)
                    }

                    // Title & description
                    VStack(spacing: 6) {
                        Text(achievement.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.quordlePrimaryText)

                        Text(achievement.description)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.quordleSecondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    // Progress or unlocked indicator
                    if isUnlocked {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundColor(achievementColor)
                            Text("Unlocked")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.quordleSecondaryText)
                        }
                    } else {
                        // Progress bar for locked achievements
                        VStack(spacing: 8) {
                            ProgressView(value: progressFraction)
                                .tint(achievementColor)
                                .scaleEffect(y: 2)
                                .clipShape(Capsule())
                                .padding(.horizontal, 20)

                            Text("\(progress.current) / \(progress.required)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.quordleSecondaryText)
                        }
                    }

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [achievementColor, achievementColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: achievementColor.opacity(0.35), radius: 10, x: 0, y: 5)
                            )
                    }
                    .padding(.top, 4)
                }
                .padding(28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.quordleCardBackground.opacity(0.5))
                        // Shimmer for unlocked
                        if isUnlocked {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.08), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .mask(RoundedRectangle(cornerRadius: 28))
                        }
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                isUnlocked
                                    ? LinearGradient(
                                        colors: [achievementColor.opacity(0.4), achievementColor.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.quordleCardBorder.opacity(0.5), Color.quordleCardBorder.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
                )
                .padding(.horizontal, 32)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                ringProgress = isUnlocked ? 1.0 : progressFraction
            }
            if isUnlocked {
                withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                    shimmerOffset = 200
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            appeared = false
            iconScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
