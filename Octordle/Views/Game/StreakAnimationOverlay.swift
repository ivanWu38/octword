import SwiftUI

/// Full-screen streak celebration shown after a daily puzzle ends (win or loss).
/// Plays for ~2 seconds with auto-dismiss; tap anywhere to skip early.
/// Calls `onDismiss` once the exit animation completes so the parent can advance
/// to the result sheet.
struct StreakAnimationOverlay: View {
    let previousStreak: Int
    let newStreak: Int
    let onDismiss: () -> Void

    @State private var displayedStreak: Int
    @State private var hasStarted = false

    // Entry / exit
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.8
    @State private var backgroundOpacity: Double = 0

    // Internal animation state
    @State private var flameScale: CGFloat = 1.0
    @State private var glowScale: CGFloat = 0.6
    @State private var glowOpacity: Double = 0
    @State private var plusOneVisible = false
    @State private var plusOneOffset: CGFloat = 0
    @State private var plusOneOpacity: Double = 1
    @State private var particleProgress: Double = 0

    @State private var dismissTimer: Timer?
    @State private var hasDismissed = false

    // Configurable timings
    private let autoDismissAfter: TimeInterval = 2.3

    init(previousStreak: Int, newStreak: Int, onDismiss: @escaping () -> Void) {
        self.previousStreak = previousStreak
        self.newStreak = newStreak
        self.onDismiss = onDismiss
        self._displayedStreak = State(initialValue: previousStreak)
    }

    var body: some View {
        ZStack {
            // Dim backdrop — also catches tap-to-skip
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    skip()
                }

            // Centered content
            VStack(spacing: 26) {
                // Flame area: glow ring, particles, flame, +1 floater
                ZStack {
                    // Soft radial glow behind flame
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.quordleOrange.opacity(0.55),
                                    Color.quordleOrange.opacity(0)
                                ],
                                center: .center,
                                startRadius: 12,
                                endRadius: 130
                            )
                        )
                        .frame(width: 260, height: 260)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)

                    // Particles
                    ForEach(0..<10, id: \.self) { particle(index: $0) }

                    // The hero flame
                    Image(systemName: "flame.fill")
                        .font(.system(size: 130))
                        .foregroundColor(.quordleOrange)
                        .scaleEffect(flameScale)
                        .shadow(color: .quordleOrange.opacity(0.7), radius: 28, x: 0, y: 6)

                    // "+1" floater
                    if plusOneVisible {
                        Text("+1")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.quordleOrange)
                            .offset(x: 92, y: plusOneOffset)
                            .opacity(plusOneOpacity)
                            .shadow(color: .quordleOrange.opacity(0.6), radius: 8)
                    }
                }
                .frame(width: 260, height: 200)

                // Big streak number with count-up
                Text("\(displayedStreak)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .shadow(color: .quordleOrange.opacity(0.6), radius: 14)

                // Label
                Text("DAY STREAK")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.85))
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            startSequence()
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }

    // MARK: - Sequence

    private func startSequence() {
        // 1) Backdrop fades in
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 0.62
        }

        // 2) Content scales / fades in (spring for a soft pop)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            contentOpacity = 1
            contentScale = 1
        }

        // 3) After content settles, run the flame animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Glow ring expands and brightens
            withAnimation(.easeOut(duration: 0.45)) {
                glowScale = 1.7
                glowOpacity = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.7)) {
                    glowOpacity = 0.35
                }
            }

            // Number count-up
            withAnimation(.easeInOut(duration: 0.5)) {
                displayedStreak = newStreak
            }

            // Flame pulse
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                flameScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.35)) {
                    flameScale = 1.0
                }
            }

            // Particles fly outward
            withAnimation(.easeOut(duration: 1.1)) {
                particleProgress = 1
            }

            // Haptic
            HapticManager.shared.streakIncrement()

            // +1 floater — drifts up slowly with a long fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                plusOneVisible = true
                withAnimation(.easeOut(duration: 1.4)) {
                    plusOneOffset = -100
                    plusOneOpacity = 0
                }
            }
        }

        // 4) Auto-dismiss after 2s
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { _ in
            DispatchQueue.main.async {
                exit()
            }
        }
    }

    // MARK: - Dismissal

    private func skip() {
        dismissTimer?.invalidate()
        exit()
    }

    private func exit() {
        guard !hasDismissed else { return }
        hasDismissed = true

        withAnimation(.easeIn(duration: 0.3)) {
            contentOpacity = 0
            contentScale = 0.9
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            onDismiss()
        }
    }

    // MARK: - Particles

    @ViewBuilder
    private func particle(index: Int) -> some View {
        // Predetermined offsets — natural-looking but deterministic
        let angles: [Double] = [-90, -110, -70, -130, -50, -100, -120, -60, -140, -40]
        let distances: [Double] = [85, 95, 90, 80, 100, 88, 92, 95, 80, 100]
        let sizes: [CGFloat] = [6, 5, 7, 4, 6, 5, 5, 6, 4, 7]

        let angle = angles[index] * .pi / 180
        let distance = distances[index]
        let size = sizes[index]

        let dx = CGFloat(cos(angle) * distance * particleProgress)
        let dy = CGFloat(sin(angle) * distance * particleProgress)

        Circle()
            .fill(Color.quordleOrange)
            .frame(width: size, height: size)
            .offset(x: dx, y: dy)
            .opacity(1 - particleProgress)
            .shadow(color: .quordleOrange.opacity(0.65), radius: 5)
    }
}
