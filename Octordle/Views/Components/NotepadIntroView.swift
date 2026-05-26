import SwiftUI

/// One-time intro card for the notepad feature
struct NotepadIntroView: View {
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.3
    @State private var shimmerOffset: CGFloat = -200

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
                    // Icon
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.quordlePrimary.opacity(0.20))
                            .frame(width: 120, height: 120)
                            .blur(radius: 25)

                        // Icon background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.quordlePrimary.opacity(0.25), Color.quordlePrimary.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        // Pencil icon
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.quordlePrimary, Color.quordlePrimary.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(iconScale)
                    }

                    // Title & description
                    VStack(spacing: 10) {
                        Text("NEW")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.quordlePrimary)
                            .tracking(1)

                        Text("Notepad")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.quordlePrimaryText)

                        Text("Jot down your thoughts while playing.\nTap the pencil icon anytime to open it.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.quordleSecondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    // Pencil icon preview
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.quordlePrimary)

                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundColor(.quordleSecondaryText.opacity(0.5))

                        Text("Look for this icon")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.quordleSecondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.quordlePrimary.opacity(0.08))
                    )

                    // Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Got it!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.quordlePrimary, Color.quordlePrimary.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.quordlePrimary.opacity(0.35), radius: 10, x: 0, y: 5)
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
                                    colors: [Color.quordlePrimary.opacity(0.4), Color.quordlePrimary.opacity(0.15)],
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
            withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                shimmerOffset = 200
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
