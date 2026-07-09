import SwiftUI

/// Beautiful notification card when a new theme is unlocked
struct ThemeUnlockView: View {
    let theme: BoardTheme
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.3
    @State private var shimmerOffset: CGFloat = -200
    @State private var colorPulse = false

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
                    // Theme color showcase
                    ZStack {
                        // Outer glow with theme colors
                        Circle()
                            .fill(theme.correctColor.opacity(0.20))
                            .frame(width: 130, height: 130)
                            .blur(radius: 25)

                        // Color ring
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [theme.correctColor, theme.presentColor, theme.correctColor],
                                    center: .center
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(colorPulse ? 360 : 0))

                        // Inner circle with theme colors
                        HStack(spacing: 0) {
                            Circle()
                                .fill(theme.correctColor)
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(theme.presentColor)
                                .frame(width: 36, height: 36)
                        }
                        .scaleEffect(iconScale)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("THEME UNLOCKED")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(theme.correctColor)
                            .tracking(1)

                        Text(theme.displayName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.quordlePrimaryText)

                        Text(theme.unlockDescription)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.quordleSecondaryText)
                    }

                    // Preview tiles
                    HStack(spacing: 6) {
                        themePreviewTile(color: theme.correctColor, letter: "Q")
                        themePreviewTile(color: theme.presentColor, letter: "U")
                        themePreviewTile(color: theme.absentColor, letter: "O")
                        themePreviewTile(color: theme.emptyColor, letter: "R", isEmpty: true)
                        themePreviewTile(color: theme.emptyColor, letter: "D", isEmpty: true)
                    }

                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            ThemeService.shared.selectedTheme = theme
                            HapticManager.shared.primaryTap()
                            dismiss()
                        } label: {
                            Text("Apply Now")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                colors: [theme.correctColor, theme.presentColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: theme.correctColor.opacity(0.35), radius: 10, x: 0, y: 5)
                                )
                        }

                        Button {
                            HapticManager.shared.backTap()
                            dismiss()
                        } label: {
                            Text("Maybe Later")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.quordleSecondaryText)
                        }
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
                        // Shimmer
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
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [theme.correctColor.opacity(0.4), theme.presentColor.opacity(0.2)],
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
            HapticManager.shared.achievementUnlocked()
            SoundManager.shared.play(.solved)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) {
                iconScale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                shimmerOffset = 200
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(0.3)) {
                colorPulse = true
            }
        }
    }

    private func themePreviewTile(color: Color, letter: String, isEmpty: Bool = false) -> some View {
        Text(letter)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(isEmpty ? .quordlePrimaryText : .white)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isEmpty ? theme.emptyBorderColor : Color.clear, lineWidth: isEmpty ? 2 : 0)
            )
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
