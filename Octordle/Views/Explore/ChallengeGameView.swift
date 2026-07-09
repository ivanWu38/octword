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
    @State private var showReview = false

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
            // Run mode pauses on a per-round result card until the player continues.
            if let card = session.pendingRoundCard, !session.isOver {
                RunRoundCard(
                    result: card,
                    livesLeft: session.livesLeft,
                    onContinue: {
                        HapticManager.shared.buttonTap()
                        session.clearPendingRoundCard()
                        roundEpoch += 1   // deal the next round
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if session.isOver {
                endOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isOver)
        .animation(.easeInOut(duration: 0.25), value: session.pendingRoundCard?.id)
        .sheet(isPresented: $showReview) {
            ChallengeReviewView(rounds: session.rounds)
        }
        .onAppear {
            session.start()
        }
        .onChange(of: session.gamesCompleted) { _ in
            // Timed flows continuously with a quick toast; Run shows a full card.
            if session.preset.family == .timed { showRoundToast() }
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

                    Text("· \(min(session.gamesCompleted + 1, session.preset.gameTarget))/\(session.preset.gameTarget)")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                        .monospacedDigit()
                } else {
                    livesView

                    Text("· Round \(session.gamesCompleted + 1)")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
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
        Text("\(max(0, session.livesLeft))")
            .font(.system(.subheadline, design: .serif))
            .fontWeight(.bold)
            .foregroundColor(session.livesLeft <= 1 ? .red : .quordlePrimaryText)
            .monospacedDigit()
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

    private var endTitle: String {
        if session.preset.family == .run { return "Out of Lives" }
        return session.didCompleteGoal ? "Challenge Complete" : "Time's Up"
    }

    private func endStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.quordleSecondaryText)
        }
    }

    private var endOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(endTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(session.didCompleteGoal ? .quordleGold : .quordleSecondaryText)
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

                HStack(spacing: 22) {
                    if session.preset.family == .timed {
                        endStat("\(session.gamesCompleted)/\(session.preset.gameTarget)", "games")
                    } else {
                        endStat("\(session.gamesCompleted)", "rounds")
                        endStat("\(session.flawlessRounds)", "flawless")
                    }
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

                    if !session.rounds.isEmpty {
                        Button {
                            HapticManager.shared.buttonTap()
                            showReview = true
                        } label: {
                            Text("Review")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.top, 2)
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

// MARK: - Run per-round result card

/// Shown between rounds in Run mode: reveals this round's answers (missed words
/// in red), an encouraging line, remaining lives, and a Continue button. A
/// flawless round (all solved) gets confetti and gold styling.
private struct RunRoundCard: View {
    let result: ChallengeSession.RoundResult
    let livesLeft: Int
    let onContinue: () -> Void

    private var flawless: Bool { result.isFlawless }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            if flawless {
                ConfettiView().ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if flawless {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                        Text("Flawless")
                            .font(.system(size: 12, weight: .heavy)).tracking(1).textCase(.uppercase)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(Color.quordleGold))
                    .padding(.top, 22)
                } else {
                    Text("Round \(result.id) complete")
                        .font(.system(size: 11, weight: .semibold)).tracking(2).textCase(.uppercase)
                        .foregroundColor(.quordleSecondaryText)
                        .padding(.top, 24)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(result.solvedCount)")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundColor(flawless ? .quordleGold : .quordlePrimaryText)
                    Text("/ \(result.total)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                }
                .padding(.top, flawless ? 12 : 6)

                Text("words this round")
                    .font(.system(size: 13))
                    .foregroundColor(.quordleSecondaryText)

                Text(encouragement)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                HStack(spacing: 5) {
                    Image(systemName: "heart.fill").font(.system(size: 12))
                    Text("\(livesLeft) \(livesLeft == 1 ? "life" : "lives") left")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                }
                .foregroundColor(.quordlePrimary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.quordlePrimary.opacity(0.10)))
                .padding(.top, 12)

                Text("The Answers")
                    .font(.system(size: 10.5, weight: .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.top, 18)

                answersGrid
                    .padding(.top, 10)

                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 18)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.quordleCardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.quordleCardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 24)
        }
    }

    private var answersGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)]
        return LazyVGrid(columns: cols, spacing: 7) {
            ForEach(Array(result.words.enumerated()), id: \.offset) { index, word in
                let solved = result.solved[index]
                HStack {
                    Text(word.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(solved ? .quordlePrimaryText : .quordlePrimary)
                    Spacer(minLength: 4)
                    Image(systemName: solved ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(solved ? .quordleCorrect : .quordlePrimary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(solved ? Color.quordleBackground : Color.quordlePrimary.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(solved ? Color.quordleCardBorder : Color.quordlePrimary.opacity(0.5), lineWidth: 1))
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var encouragement: String {
        let s = result.solvedCount, t = result.total
        if s == t { return "Clean sweep! No lives lost. 🔥" }
        if s >= t - 1 { return "So close — one slipped away." }
        if s * 2 >= t { return "Solid round. Keep the streak going." }
        return "Shake it off — next round's yours."
    }
}

// MARK: - Review (boards + answers, per game)

/// Editorial recap: switch between games, view each game's board grids (with your
/// colored guesses) or a per-board answer list. The only way to see answers for
/// Timed mode, and a full re-look at any round.
private struct ChallengeReviewView: View {
    let rounds: [ChallengeSession.RoundResult]
    @Environment(\.dismiss) private var dismiss

    private enum Tab { case boards, answers }
    @State private var tab: Tab = .boards
    @State private var gameIndex: Int

    init(rounds: [ChallengeSession.RoundResult]) {
        self.rounds = rounds
        _gameIndex = State(initialValue: max(0, rounds.count - 1))
    }

    private var round: ChallengeSession.RoundResult? {
        guard rounds.indices.contains(gameIndex) else { return nil }
        return rounds[gameIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            stepper
            Divider().overlay(Color.quordleCardBorder)

            if let round {
                if tab == .boards {
                    boardsView(round)
                } else {
                    answersView(round)
                }
            } else {
                Spacer()
            }
        }
        .background(Color.quordleBackground.ignoresSafeArea())
    }

    // MARK: Header (masthead-style, dark serif title)

    private var header: some View {
        VStack(spacing: 0) {
            Text("Challenge Recap")
                .font(.system(size: 10.5, weight: .semibold)).tracking(2).textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            HStack {
                Button {
                    HapticManager.shared.buttonTap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Review")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Underline tabs

    private var tabs: some View {
        HStack(spacing: 34) {
            tabButton("Boards", .boards)
            tabButton("Answers", .answers)
        }
        .padding(.top, 14)
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        let active = tab == value
        return Button {
            HapticManager.shared.buttonTap()
            tab = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .serif))
                .tracking(1.5).textCase(.uppercase)
                .foregroundColor(active ? .quordlePrimary : .quordleSecondaryText)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(active ? Color.quordlePrimary : .clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Game stepper

    private var stepper: some View {
        HStack(spacing: 18) {
            stepArrow("chevron.left", enabled: gameIndex > 0) { gameIndex -= 1 }

            VStack(spacing: 2) {
                if let round {
                    HStack(spacing: 4) {
                        Text("Game \(round.id)")
                            .font(.system(size: 19, weight: .bold, design: .serif))
                            .foregroundColor(.quordlePrimaryText)
                        if let last = rounds.last {
                            Text("/ \(last.id)")
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(.quordleSecondaryText)
                        }
                    }
                    Text("\(round.solvedCount) of \(round.total) solved")
                        .font(.system(size: 11.5, weight: .semibold)).tracking(1).textCase(.uppercase)
                        .foregroundColor(round.isFlawless ? .quordleGold : .quordleSecondaryText)
                }
            }
            .frame(minWidth: 150)

            stepArrow("chevron.right", enabled: gameIndex < rounds.count - 1) { gameIndex += 1 }
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private func stepArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(enabled ? .quordlePrimaryText : .quordleCardBorder)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Color.quordleCardBackground)
                        .overlay(Circle().stroke(Color.quordleCardBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Boards tab

    private func boardsView(_ round: ChallengeSession.RoundResult) -> some View {
        GeometryReader { geo in
            let interBoard: CGFloat = 10
            let hPad: CGFloat = 16
            let cardPad: CGFloat = 8
            let boardWidth = (geo.size.width - hPad * 2 - interBoard) / 2
            let tileSpacing = Constants.Layout.tileSpacing
            let tileSize = max(0, (boardWidth - cardPad * 2 - 4 * tileSpacing) / 5)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(boardWidth), spacing: interBoard),
                                    GridItem(.fixed(boardWidth), spacing: interBoard)], spacing: 12) {
                    ForEach(Array(round.boards.enumerated()), id: \.offset) { index, board in
                        VStack(spacing: 6) {
                            HStack {
                                Text("Board \(index + 1)")
                                    .font(.system(size: 9, weight: .bold)).tracking(0.5).textCase(.uppercase)
                                    .foregroundColor(.quordleSecondaryText)
                                Spacer()
                                if board.isSolved {
                                    Text("\(board.solvedAtGuess ?? 0)")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(.quordleCorrect)
                                } else {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(.quordlePrimary)
                                }
                            }
                            BoardView(board: board, currentInput: "", boardIndex: index, tileSize: tileSize)
                        }
                        .padding(cardPad)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.quordleCardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quordleCardBorder, lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Answers tab

    private func answersView(_ round: ChallengeSession.RoundResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(round.boards.enumerated()), id: \.offset) { index, board in
                    HStack(spacing: 12) {
                        Text("Board \(index + 1)")
                            .font(.system(size: 10, weight: .bold)).tracking(0.5).textCase(.uppercase)
                            .foregroundColor(.quordleSecondaryText)
                            .frame(width: 62, alignment: .leading)

                        Text(board.targetWord)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(board.isSolved ? .quordlePrimaryText : .quordlePrimary)

                        Spacer()

                        if board.isSolved {
                            Text("solved · \(board.solvedAtGuess ?? 0)")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.quordleSecondaryText)
                        } else {
                            Text("missed ✗")
                                .font(.system(size: 12, weight: .semibold, design: .serif))
                                .foregroundColor(.quordlePrimary)
                        }
                    }
                    .padding(.vertical, 12)
                    Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    NavigationStack {
        ChallengeGameView(preset: .timedQuick)
            .environmentObject(ThemeService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}
