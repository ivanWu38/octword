import SwiftUI

/// Hosts a Challenge session: a slim HUD (clock/lives + running score) above the
/// live `GameView`, an inter-round toast while the next board deals itself in, and
/// a full end-of-session overlay once the clock/lives run out.
///
/// `GameViewModel` reports each round's result into `session` from `endGame()`
/// (see `GameViewModel.challengeSession`); this view just reacts to the session's
/// published state — it never talks to the view model directly.
struct ChallengeGameView: View {
    @StateObject private var session: ChallengeSession
    @Environment(\.dismiss) private var dismiss

    /// Bumped to force a fresh `GameView`/`GameViewModel` pair on "Play Again"
    /// (the session itself is reset in place, see `ChallengeSession.reset()`).
    @State private var roundEpoch = 0
    @State private var toastText: String?
    @State private var lastReportedTotal = 0

    init(preset: ChallengeType) {
        _session = StateObject(wrappedValue: ChallengeSession(preset: preset))
    }

    var body: some View {
        VStack(spacing: 0) {
            hudStrip

            ZStack(alignment: .top) {
                GameView(challenge: session)
                    .id(roundEpoch)

                if let toastText {
                    toastView(toastText)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toastText)
        .background(Color.quordleBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if session.isOver {
                endOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isOver)
        .onAppear {
            session.start()
        }
        .onChange(of: session.gamesCompleted) { _ in
            showRoundToast()
        }
    }

    // MARK: - HUD

    private var hudStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: session.preset.family == .timed ? "stopwatch" : "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.quordlePrimary)

                if session.preset.family == .timed {
                    Text(timeString)
                        .font(.system(.subheadline, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(session.remainingSeconds <= 10 ? .red : .quordlePrimaryText)
                        .monospacedDigit()
                } else {
                    livesView
                }
            }

            Spacer()

            Text(session.preset.name)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)

            Spacer()

            HStack(spacing: 4) {
                Text("\(session.totalBoardsSolved)")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                Text("solved")
                    .font(.caption)
                    .foregroundColor(.quordleSecondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.quordleBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
        }
    }

    private var timeString: String {
        let minutes = session.remainingSeconds / 60
        let seconds = session.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var livesView: some View {
        HStack(spacing: 3) {
            ForEach(0..<session.preset.config, id: \.self) { i in
                Image(systemName: i < session.livesLeft ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundColor(i < session.livesLeft ? .quordlePrimary : .quordleSecondaryText.opacity(0.35))
            }
        }
    }

    // MARK: - Inter-round toast

    private func showRoundToast() {
        guard !session.isOver else { return }
        let solvedThisRound = max(0, session.totalBoardsSolved - lastReportedTotal)
        lastReportedTotal = session.totalBoardsSolved
        toastText = "Round complete · +\(solvedThisRound) ✓ · next round…"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            toastText = nil
        }
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .serif))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.quordlePrimary))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    // MARK: - End Overlay

    private var endOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(session.preset.family == .timed ? "Time's Up" : "Out of Lives")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.top, 28)

                Text("\(session.totalBoardsSolved)")
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .padding(.top, 6)

                Text("boards solved")
                    .font(.system(size: 13))
                    .foregroundColor(.quordleSecondaryText)

                if session.isNewBest {
                    Text("New Best!")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundColor(.quordleGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color.quordleGold, lineWidth: 1))
                        .padding(.top, 12)
                } else if session.bestScore > 0 {
                    Text("Best \(session.bestScore)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                        .padding(.top, 12)
                }

                Rectangle().fill(Color.quordleCardBorder).frame(height: 1).padding(.top, 20)

                HStack(spacing: 6) {
                    Text("\(session.gamesCompleted)")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(session.gamesCompleted == 1 ? "game played" : "games played")
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    Button {
                        HapticManager.shared.buttonTap()
                        lastReportedTotal = 0
                        session.reset()
                        roundEpoch += 1
                    } label: {
                        Text("Play Again")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 22)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}

#Preview {
    NavigationStack {
        ChallengeGameView(preset: .timedQuick)
            .environmentObject(ThemeService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}
