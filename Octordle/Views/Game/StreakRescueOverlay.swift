import SwiftUI

/// Shown after finishing today's edition when yesterday was missed and the streak
/// before it is worth restoring. Replaces the "0 → 1" flame animation for that case:
/// a dimmed flame, the broken number struck through, and a notice offering to bring
/// the streak back with a rewarded ad (free for Premium).
struct StreakRescueOverlay: View {
    let brokenStreak: Int
    let isPremium: Bool
    let onRestore: () async -> RewardedAdManager.Outcome
    let onRestored: () -> Void
    let onStartFresh: () -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.85
    @State private var isWorking = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 88))
                        .foregroundColor(Color(white: 0.55))
                    Image(systemName: "wind")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .offset(x: 32, y: -54)
                }
                .frame(height: 110)

                Text("\(brokenStreak)")
                    .font(.system(size: 80, weight: .bold, design: .serif))
                    .foregroundColor(.white.opacity(0.6))
                    .overlay(
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.47, blue: 0.31))
                            .frame(height: 6)
                            .rotationEffect(.degrees(-4))
                    )

                Text("DAY STREAK · ENDED YESTERDAY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Bring it back?")
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)

                    Text(isPremium
                         ? "You missed yesterday's edition. As a Premium reader you can restore your \(brokenStreak)-day streak — today counts too."
                         : "You missed yesterday's edition. Watch a short ad and your \(brokenStreak)-day streak is restored — today counts too.")
                        .font(.system(size: 13.5, design: .serif))
                        .italic()
                        .foregroundColor(.quordleSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: restore) {
                        HStack(spacing: 9) {
                            if isWorking {
                                ProgressView().tint(.quordleBackgroundSecondary)
                            } else if !isPremium {
                                Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                            }
                            Text("Restore my streak")
                                .font(.system(size: 17, weight: .bold, design: .serif))
                        }
                        .foregroundColor(.quordleBackgroundSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.quordlePrimary))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isWorking)
                    .padding(.top, 8)

                    Button {
                        guard !isWorking else { return }
                        HapticManager.shared.buttonTap()
                        AnalyticsService.logStreakRescue("declined", surface: "overlay", streak: brokenStreak)
                        exit(then: onStartFresh)
                    } label: {
                        Text("Start fresh from 1")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.quordleSecondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if let toast {
                        Text(toast)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.quordleOrange)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.quordleCardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.quordleCardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 22)
                .padding(.top, 6)
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .onAppear {
            AnalyticsService.logStreakRescue("offered", surface: "overlay", streak: brokenStreak)
            withAnimation(.easeOut(duration: 0.3)) { backgroundOpacity = 0.66 }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                contentOpacity = 1
                contentScale = 1
            }
        }
    }

    private func restore() {
        guard !isWorking else { return }
        HapticManager.shared.buttonTap()
        AnalyticsService.logStreakRescue("accepted", surface: "overlay", streak: brokenStreak)
        isWorking = true
        Task { @MainActor in
            let outcome = await onRestore()
            isWorking = false
            switch outcome {
            case .earned:
                DailyPuzzleService.shared.rescueStreak()
                AnalyticsService.logStreakRescue("completed", surface: "overlay", streak: brokenStreak)
                HapticManager.shared.streakMilestone()
                exit(then: onRestored)
            case .dismissed:
                withAnimation { toast = "Watch the whole ad to restore your streak" }
            case .unavailable:
                AnalyticsService.logStreakRescue("ad_unavailable", surface: "overlay", streak: brokenStreak)
                withAnimation { toast = AdCopy.notReady }
            }
        }
    }

    private func exit(then completion: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.25)) {
            contentOpacity = 0
            contentScale = 0.92
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) { completion() }
    }
}
