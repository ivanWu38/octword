import SwiftUI

/// Main game view with Octordle board layout
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var showConfetti = false
    @State private var shouldDismissAfterResult = false
    @State private var showResultSheet = false
    @State private var topVisibleRow: Int = 0
    @State private var notepadOffset: CGSize = .zero
    @State private var notepadDragStart: CGSize = .zero
    @FocusState private var isNotepadFocused: Bool
    @State private var showNotepadIntro = false
    @State private var showThemeUnlock = false
    @State private var showAchievementUnlock = false
    @State private var showStreakOverlay = false
    @State private var streakSnapPrev: Int = 0
    @State private var streakSnapNew: Int = 0
    /// True while the player is studying the board after finishing (they tapped
    /// "View Board"). Keeps the game on screen and shows the re-open Results button.
    @State private var reviewingBoard = false
    /// Set once the player has reached the result card. After that, re-opening the
    /// results goes straight to the card and skips the report-first reveal.
    @State private var hasReachedResultCard = false
    @State private var showHowToPlay = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var reviewManager = ReviewManager.shared

    /// Explore modes (category packs + timed/run challenges) have special rules
    /// worth a How-to-Play card; daily/unlimited are the standard game.
    private var isExploreGame: Bool {
        viewModel.challengeSession != nil || viewModel.gameState.mode == .categories
    }

    /// Mode-specific How-to-Play content, with the current preset/pack's numbers.
    private var howToPlayContent: HowToPlayContent? {
        if let session = viewModel.challengeSession {
            return .forChallenge(session.preset)
        }
        if viewModel.gameState.mode == .categories,
           let id = viewModel.currentCategoryId,
           let category = CategoryService.shared.categories.first(where: { $0.id == id }) {
            return .forCategory(category)
        }
        return nil
    }

    init(mode: GameMode, difficulty: Difficulty) {
        _viewModel = StateObject(wrappedValue: GameViewModel(mode: mode, difficulty: difficulty))
    }

    init(resuming state: GameState) {
        _viewModel = StateObject(wrappedValue: GameViewModel(resuming: state))
    }

    init(archiveDate: Date) {
        _viewModel = StateObject(wrappedValue: GameViewModel(archiveDate: archiveDate))
    }

    init(category: WordCategory, puzzleIndex: Int) {
        _viewModel = StateObject(wrappedValue: GameViewModel(category: category, puzzleIndex: puzzleIndex))
    }

    /// A Challenge round (Timed/Run). The result sheet, confetti, streak overlay,
    /// and achievement/theme cards never trigger here — `challengeSession` being
    /// set makes `endGame()` report to the session instead of setting
    /// `showGameCompleteSheet`, so all of that stays naturally dormant. The parent
    /// `ChallengeGameView` hosts the HUD, inter-round toast, and end-of-session
    /// overlay around this view.
    init(challenge session: ChallengeSession) {
        _viewModel = StateObject(wrappedValue: GameViewModel(challenge: session))
    }

    var body: some View {
        GeometryReader { geometry in
            let maxContentWidth: CGFloat = 600
            let contentWidth = min(geometry.size.width, maxContentWidth)
            let keyboardHeight: CGFloat = 180
            let topBarHeight: CGFloat = 50
            let adHeight: CGFloat = subscriptionService.isPremium ? 0 : 60
            let availableHeight = max(0, geometry.size.height - keyboardHeight - topBarHeight - adHeight - 16)
            let availableWidth = max(0, contentWidth - 16)

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .frame(height: topBarHeight)

                // 2x2 Board Grid
                boardGrid(availableWidth: availableWidth, availableHeight: availableHeight)
                    .frame(height: availableHeight)

                Spacer(minLength: 4)

                // Keyboard — hidden when notepad is open (system keyboard takes over)
                if !viewModel.isNotepadOpen {
                    KeyboardView(
                        perBoardStates: viewModel.perBoardLetterStates,
                        boardCount: viewModel.keyboardBoardCount,
                        availableWidth: contentWidth,
                        onKeyTap: viewModel.addLetter,
                        onDelete: viewModel.removeLetter,
                        onSubmit: viewModel.submitGuess
                    )
                    .frame(height: keyboardHeight)
                }

                // Ad banner (non-premium)
                if !subscriptionService.isPremium {
                    BannerAdView()
                        .frame(height: adHeight)
                }
            }
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .center) {
                if viewModel.showInvalidWordAlert {
                    invalidWordBanner
                }
            }
            .overlay {
                if viewModel.isNotepadOpen {
                    notepadView(availableHeight: availableHeight)
                        .offset(y: -(availableHeight * 0.12))
                }
            }
            .background(Color.quordleBackground.ignoresSafeArea())
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottom) {
            if reviewingBoard && !showResultSheet {
                reopenResultButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: reviewingBoard)
        .overlay {
            if showHowToPlay, let content = howToPlayContent {
                HowToPlayCard(content: content) {
                    withAnimation(.easeInOut(duration: 0.2)) { showHowToPlay = false }
                }
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar) // 隐藏底部 Tab Bar
        .sheet(isPresented: $showResultSheet, onDismiss: {
            // Player tapped "View Board": keep the game on screen so they can study
            // their guesses for as long as they like. Don't run the leave flow — the
            // floating "View Results" button lets them re-open this card anytime.
            if reviewingBoard { return }

            // NOTE: the daily is marked completed at the very end, together with the
            // pop (see proceedAfterResult / review onDismiss). Marking here would swap
            // DailyView's root from start → completed while GameView is still pushed,
            // which can make the navigationDestination rebuild a fresh GameView.

            // Show unlock cards in sequence: achievements → theme → review.
            if !viewModel.newlyUnlockedAchievements.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAchievementUnlock = true
                }
                return
            }

            if viewModel.newlyUnlockedTheme != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showThemeUnlock = true
                }
                return
            }

            proceedAfterResult()
        }) {
            PostGameFlowView(
                viewModel: viewModel,
                puzzleNumber: viewModel.gameState.mode == .daily ? DailyPuzzleService.shared.puzzleNumber : nil,
                startAtResult: hasReachedResultCard,
                onReviewBoard: {
                    // Keep the game on screen; just slide the result card away.
                    // The player has now seen the result card, so future re-opens
                    // go straight back to it (skipping the report-first reveal).
                    reviewingBoard = true
                    hasReachedResultCard = true
                    showResultSheet = false
                },
                onDone: {
                    // Explicit "leave" — clear the review flag so onDismiss runs the
                    // unlock/exit flow.
                    reviewingBoard = false
                    showResultSheet = false
                }
            )
            .interactiveDismissDisabled()
        }
        .overlay {
            if showConfetti {
                ConfettiView()
            }
        }
        .overlay {
            if showStreakOverlay {
                StreakAnimationOverlay(
                    previousStreak: streakSnapPrev,
                    newStreak: streakSnapNew,
                    onDismiss: {
                        showStreakOverlay = false
                        // Brief beat before the result sheet slides up
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showResultSheet = true
                        }
                    }
                )
            }
        }
        .overlay {
            if showNotepadIntro {
                NotepadIntroView {
                    showNotepadIntro = false
                }
            }
        }
        .overlay {
            if showAchievementUnlock, let achievement = viewModel.newlyUnlockedAchievements.first {
                AchievementUnlockView(achievement: achievement) {
                    if !viewModel.newlyUnlockedAchievements.isEmpty {
                        viewModel.newlyUnlockedAchievements.removeFirst()
                    }
                    advanceAfterAchievement()
                }
            }
        }
        .overlay {
            if showThemeUnlock, let theme = viewModel.newlyUnlockedTheme {
                ThemeUnlockView(theme: theme) {
                    viewModel.newlyUnlockedTheme = nil
                    showThemeUnlock = false
                    proceedAfterResult()
                }
            }
        }
        .sheet(isPresented: $shouldDismissAfterResult, onDismiss: {
            // After the review prompt closes, mark completed and pop together.
            viewModel.markDailyCompletedIfNeeded()
            dismiss()
        }) {
            ReviewPromptView(
                onAccept: {
                    reviewManager.userAccepted()
                    shouldDismissAfterResult = false
                },
                onDecline: {
                    reviewManager.userDeclined()
                    shouldDismissAfterResult = false
                }
            )
        }
        .onChange(of: viewModel.showGameCompleteSheet) { newValue in
            guard newValue else { return }

            // Decide if the streak overlay should play (daily, first play of today only).
            // Capture streak values BEFORE markTodayCompleted is called (which happens
            // when the result sheet is dismissed) so previous→new is correct.
            let shouldShowStreak = viewModel.gameState.mode == .daily
                && !DailyPuzzleService.shared.isTodayCompleted
            if shouldShowStreak {
                streakSnapPrev = DailyPuzzleService.shared.currentStreak
                streakSnapNew = streakSnapPrev + 1
            }

            if viewModel.gameState.isWon {
                // Won: play confetti first, then streak overlay (or skip to result)
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Animation.confettiDuration) {
                    if shouldShowStreak {
                        showStreakOverlay = true
                    } else {
                        showResultSheet = true
                    }
                }
            } else {
                // Lost: skip confetti, go straight to streak overlay (or result)
                if shouldShowStreak {
                    showStreakOverlay = true
                } else {
                    showResultSheet = true
                }
            }
        }
        .onAppear {
            NotificationCenter.default.post(name: .hideTabBar, object: nil)

            // Show notepad intro once
            if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasSeenNotepadIntro) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showNotepadIntro = true
                    UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasSeenNotepadIntro)
                }
            }

            #if DEBUG
            // TEMPORARY QA: auto-finish the game to test achievement cards. Remove later.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                viewModel.debugAutoPlay()
            }
            #endif
        }
        .onDisappear {
            if !viewModel.isGameOver && viewModel.guessCount > 0 {
                AnalyticsService.logGameAbandon(gameState: viewModel.gameState)
            }
            viewModel.pauseGame()
            NotificationCenter.default.post(name: .showTabBar, object: nil)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                viewModel.resumeGame()
            } else {
                viewModel.pauseGame()
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Title and Timer (centered)
            HStack(spacing: 8) {
                Text(viewModel.gameState.mode == .daily
                     ? "Octordle · No.\(DailyPuzzleService.shared.puzzleNumber)"
                     : viewModel.gameState.difficulty.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)

                // Challenge rounds show the session clock in the HUD strip above,
                // so the per-game count-up timer would be a confusing second clock.
                if viewModel.challengeSession == nil {
                    Text(viewModel.elapsedTimeString)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                        .monospacedDigit()
                }
            }

            // Back button (left) and Remaining guesses (right)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.quordlePrimaryText)
                }
                .buttonStyle(ScaleButtonStyle())

                // Explore modes (Word Pack / Timed / Run) have special rules — a
                // "?" opens a mode-specific How-to-Play card.
                if isExploreGame {
                    Button {
                        HapticManager.shared.buttonTap()
                        withAnimation(.easeInOut(duration: 0.2)) { showHowToPlay = true }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.quordleSecondaryText)
                    }
                    .padding(.leading, 14)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Notepad toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isNotepadOpen.toggle()
                        }
                        if !viewModel.isNotepadOpen {
                            isNotepadFocused = false
                        }
                        HapticManager.shared.buttonTap()
                    } label: {
                        Image(systemName: viewModel.isNotepadOpen ? "pencil.circle.fill" : "pencil.circle")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.isNotepadOpen ? .quordlePrimary : .quordleSecondaryText)
                    }

                    // Remaining guesses
                    HStack(spacing: 4) {
                        Text("\(viewModel.remainingGuesses)")
                            .font(.title2.bold())
                            .foregroundColor(viewModel.remainingGuesses <= 2 ? .red : .quordlePrimaryText)

                        Text("left")
                            .font(.caption)
                            .foregroundColor(.quordleSecondaryText)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Board Grid

    private func boardGrid(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let spacing: CGFloat = 6
        let boardCount = viewModel.gameState.difficulty.boardCount
        let maxGuesses = viewModel.gameState.maxGuesses
        let tileSpacing: CGFloat = 2

        // 根據棋盤數量計算佈局
        if boardCount == 2 {
            // 2個棋盤：水平並排
            let boardWidth = max(0, (availableWidth - spacing) / 2)
            let boardHeight = availableHeight

            let tileHeight = (boardHeight - CGFloat(maxGuesses - 1) * tileSpacing) / CGFloat(maxGuesses)
            let tileWidth = (boardWidth - 4 * tileSpacing) / 5
            let tileSize = max(0, min(tileWidth, tileHeight))

            return AnyView(
                HStack(spacing: spacing) {
                    BoardView(
                        board: viewModel.boards[0],
                        currentInput: viewModel.currentGuess,
                        boardIndex: 0,
                        tileSize: tileSize
                    )
                    .frame(width: boardWidth, height: boardHeight)

                    BoardView(
                        board: viewModel.boards[1],
                        currentInput: viewModel.currentGuess,
                        boardIndex: 1,
                        tileSize: tileSize
                    )
                    .frame(width: boardWidth, height: boardHeight)
                }
                .padding(.horizontal, 8)
            )
        } else if boardCount == 8 {
            // 8個棋盤：2欄垂直捲動。一次完整顯示一排(2盤)+ 露出下一排一截，格子放大。
            // 右側上下箭頭一次推進一排。
            let arrowWidth: CGFloat = 32
            let boardAreaWidth = max(0, availableWidth - arrowWidth)
            let boardWidth = max(0, (boardAreaWidth - spacing) / 2)

            // Tiles are sized by width (2 columns) so they stay large and legible
            // regardless of guess count; the board scrolls vertically as needed.
            let tileWidth = (boardWidth - 4 * tileSpacing) / 5
            let tileSize = max(0, tileWidth)
            let rowHeight = CGFloat(maxGuesses) * tileSize + CGFloat(maxGuesses - 1) * tileSpacing

            let lastRow = 3

            return AnyView(
                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: spacing) {
                                ForEach(0..<4, id: \.self) { rowIndex in
                                    let leftIndex = rowIndex * 2
                                    let rightIndex = rowIndex * 2 + 1

                                    HStack(spacing: spacing) {
                                        BoardView(
                                            board: viewModel.boards[leftIndex],
                                            currentInput: viewModel.currentGuess,
                                            boardIndex: leftIndex,
                                            tileSize: tileSize
                                        )
                                        .frame(width: boardWidth, height: rowHeight)

                                        BoardView(
                                            board: viewModel.boards[rightIndex],
                                            currentInput: viewModel.currentGuess,
                                            boardIndex: rightIndex,
                                            tileSize: tileSize
                                        )
                                        .frame(width: boardWidth, height: rowHeight)
                                    }
                                    .id("row\(rowIndex)")
                                    .background(
                                        GeometryReader { rowGeo in
                                            Color.clear.preference(
                                                key: RowVisibilityPreferenceKey.self,
                                                value: [RowVisibility(
                                                    rowIndex: rowIndex,
                                                    minY: rowGeo.frame(in: .named("boardScroll")).minY,
                                                    maxY: rowGeo.frame(in: .named("boardScroll")).maxY
                                                )]
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .coordinateSpace(name: "boardScroll")
                        .onPreferenceChange(RowVisibilityPreferenceKey.self) { rows in
                            let row = Self.computeTopRow(rows: rows, viewportHeight: availableHeight)
                            if topVisibleRow != row {
                                topVisibleRow = row
                            }
                        }

                        // Arrow buttons on the right — step one board-row at a time
                        VStack(spacing: 16) {
                            Spacer()

                            Button {
                                HapticManager.shared.keyTap()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("row\(max(0, topVisibleRow - 1))", anchor: .top)
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(topVisibleRow > 0 ? .quordlePrimary : .quordleSecondaryText.opacity(0.4))
                                    .frame(width: arrowWidth, height: 44)
                            }
                            .disabled(topVisibleRow == 0)

                            // Position indicator: 4 segments, current board-row lit
                            VStack(spacing: 4) {
                                ForEach(0..<4, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(i == topVisibleRow
                                              ? Color.quordlePrimary
                                              : Color.quordleSecondaryText.opacity(0.25))
                                        .frame(width: 4, height: 14)
                                        .animation(.easeInOut(duration: 0.2), value: topVisibleRow)
                                }
                            }

                            Button {
                                HapticManager.shared.keyTap()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("row\(min(lastRow, topVisibleRow + 1))", anchor: .top)
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(topVisibleRow < lastRow ? .quordlePrimary : .quordleSecondaryText.opacity(0.4))
                                    .frame(width: arrowWidth, height: 44)
                            }
                            .disabled(topVisibleRow == lastRow)

                            Spacer()
                        }
                        .frame(width: arrowWidth)
                    }
                }
            )
        } else {
            // 4個棋盤：2x2 網格
            let boardWidth = max(0, (availableWidth - spacing) / 2)
            let boardHeight = max(0, (availableHeight - spacing) / 2)

            let tileHeight = (boardHeight - CGFloat(maxGuesses - 1) * tileSpacing) / CGFloat(maxGuesses)
            let tileWidth = (boardWidth - 4 * tileSpacing) / 5
            let tileSize = max(0, min(tileWidth, tileHeight))

            return AnyView(
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) {
                        BoardView(
                            board: viewModel.boards[0],
                            currentInput: viewModel.currentGuess,
                            boardIndex: 0,
                            tileSize: tileSize
                        )
                        .frame(width: boardWidth, height: boardHeight)

                        BoardView(
                            board: viewModel.boards[1],
                            currentInput: viewModel.currentGuess,
                            boardIndex: 1,
                            tileSize: tileSize
                        )
                        .frame(width: boardWidth, height: boardHeight)
                    }

                    HStack(spacing: spacing) {
                        BoardView(
                            board: viewModel.boards[2],
                            currentInput: viewModel.currentGuess,
                            boardIndex: 2,
                            tileSize: tileSize
                        )
                        .frame(width: boardWidth, height: boardHeight)

                        BoardView(
                            board: viewModel.boards[3],
                            currentInput: viewModel.currentGuess,
                            boardIndex: 3,
                            tileSize: tileSize
                        )
                        .frame(width: boardWidth, height: boardHeight)
                    }
                }
                .padding(.horizontal, 8)
            )
        }
    }

    // MARK: - Post-Result Flow

    /// Called after each achievement card is dismissed: show the next queued
    /// achievement, then fall through to the theme unlock / review flow.
    private func advanceAfterAchievement() {
        if !viewModel.newlyUnlockedAchievements.isEmpty {
            // Re-trigger the overlay so the next card animates in fresh
            showAchievementUnlock = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showAchievementUnlock = true
            }
            return
        }

        showAchievementUnlock = false

        if viewModel.newlyUnlockedTheme != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showThemeUnlock = true
            }
            return
        }

        proceedAfterResult()
    }

    // Floating button shown while reviewing the board, to bring the result card back.
    private var reopenResultButton: some View {
        Button {
            HapticManager.shared.buttonTap()
            showResultSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait")
                Text("View Results")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(Capsule().fill(Color.quordlePrimary))
            .shadow(color: Color.quordlePrimary.opacity(0.45), radius: 10, y: 4)
        }
        .padding(.bottom, subscriptionService.isPremium ? 28 : 84)
    }

    private func proceedAfterResult() {
        if reviewManager.showReviewPrompt {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shouldDismissAfterResult = true
            }
        } else {
            // Mark completed and pop in the same update so DailyView swaps to its
            // completed view exactly as GameView leaves the stack — no fresh board
            // or start screen flashing in between.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                viewModel.markDailyCompletedIfNeeded()
                dismiss()
            }
        }
    }

    // MARK: - Notepad View

    private func notepadView(availableHeight: CGFloat) -> some View {
        let notepadHeight = availableHeight * 0.42

        return VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.quordleSecondaryText.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // TextEditor
            TextEditor(text: $viewModel.notepadText)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.quordlePrimaryText)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isNotepadFocused)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            // Quick toolbar
            Divider()
                .background(Color.quordleCardBorder)

            Button {
                viewModel.notepadText += "_"
            } label: {
                Text("_")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.quordlePrimaryText)
                    .frame(width: 44, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.quordleSecondaryText.opacity(0.12))
                    )
            }
            .padding(.vertical, 6)
        }
        .frame(height: notepadHeight)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.quordleCardBackground.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.quordlePrimary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .offset(notepadOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    notepadOffset = CGSize(
                        width: notepadDragStart.width + value.translation.width,
                        height: notepadDragStart.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    notepadDragStart = notepadOffset
                }
        )
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .onAppear {
            isNotepadFocused = true
        }
    }

    // MARK: - Visible Board Computation

    /// The board-row currently occupying the most visible area (used to drive the arrows).
    private static func computeTopRow(rows: [RowVisibility], viewportHeight: CGFloat) -> Int {
        var bestRow = 0
        var bestArea: CGFloat = -1
        for row in rows {
            let visible = min(row.maxY, viewportHeight) - max(row.minY, 0)
            if visible > bestArea {
                bestArea = visible
                bestRow = row.rowIndex
            }
        }
        return bestRow
    }

    // MARK: - Invalid Word Banner

    private var invalidWordBanner: some View {
        Text(viewModel.invalidWordMessage)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.95))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .transition(.offset(y: -12).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: viewModel.showInvalidWordAlert)
    }
}

// MARK: - Scroll Visibility Tracking

private struct RowVisibility: Equatable {
    let rowIndex: Int
    let minY: CGFloat
    let maxY: CGFloat
}

private struct RowVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [RowVisibility] = []
    static func reduce(value: inout [RowVisibility], nextValue: () -> [RowVisibility]) {
        value.append(contentsOf: nextValue())
    }
}

#Preview {
    NavigationStack {
        GameView(mode: .daily, difficulty: .classic)
            .environmentObject(ThemeService.shared)
            .environmentObject(SubscriptionService.shared)
    }
}

// MARK: - How to Play

/// Mode-specific rules card for Explore games. Assumes the player already knows
/// standard Octordle — it only explains what's different about this mode, with
/// the current preset/pack's real numbers filled in.
struct HowToPlayContent {
    let kicker: String
    let title: String
    let lead: String
    let rules: [Rule]

    struct Rule: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let sub: String
    }

    static func forCategory(_ category: WordCategory) -> HowToPlayContent {
        var rules: [Rule] = [
            Rule(icon: category.symbol,
                 text: "All 8 hidden words fit \(category.name).",
                 sub: "So lean into the theme when you guess — it's your biggest hint."),
            Rule(icon: "square.grid.2x2",
                 text: "\(category.puzzleCount) puzzles in this pack.",
                 sub: "Clear one to move on to the next."),
        ]
        if !category.free {
            rules.append(Rule(icon: "lock.open",
                              text: "Locked levels open with a short ad.",
                              sub: "Once opened they stay unlocked — or get Premium for everything."))
        }
        return HowToPlayContent(
            kicker: "How to Play · Word Pack",
            title: category.name,
            lead: "Every answer fits the theme.",
            rules: rules
        )
    }

    static func forChallenge(_ preset: ChallengeType) -> HowToPlayContent {
        switch preset.family {
        case .timed:
            let minutes = preset.config / 60
            let games = preset.gameTarget
            return HowToPlayContent(
                kicker: "How to Play · Timed",
                title: preset.name,
                lead: "Race the clock.",
                rules: [
                    Rule(icon: "stopwatch",
                         text: "Finish \(games) \(games == 1 ? "puzzle" : "puzzles") within \(minutes) minutes.",
                         sub: "Do it in time and the challenge is complete."),
                    Rule(icon: "arrow.triangle.2.circlepath",
                         text: "The clock never stops.",
                         sub: "Solve one puzzle and the next starts right away."),
                    Rule(icon: "star",
                         text: "Score is the words you solved.",
                         sub: "Out of time and it ends there — then try to beat your best."),
                ]
            )
        case .run:
            let lives = preset.config
            return HowToPlayContent(
                kicker: "How to Play · Run",
                title: preset.name,
                lead: "How far can you go?",
                rules: [
                    Rule(icon: "heart.fill",
                         text: "You start with \(lives) \(lives == 1 ? "heart" : "hearts").",
                         sub: "A heart is a word you can afford to miss."),
                    Rule(icon: "heart.slash",
                         text: "Every word you miss costs 1 heart.",
                         sub: "Each round is 8 words with only 10 guesses, so misses happen."),
                    Rule(icon: "infinity",
                         text: "Still have hearts? Keep playing.",
                         sub: "Round after round — the run ends only when hearts hit 0."),
                    Rule(icon: "trophy",
                         text: "The more rounds you survive, the better.",
                         sub: "See how far you can push your streak."),
                ]
            )
        }
    }
}

/// The dimmed modal card that presents a `HowToPlayContent`.
struct HowToPlayCard: View {
    let content: HowToPlayContent
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Text(content.kicker)
                    .font(.system(size: 10.5, weight: .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.top, 22)

                Rectangle().fill(Color.quordlePrimaryText).frame(height: 1).padding(.top, 8)

                Text(content.title)
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundColor(.quordlePrimaryText)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.vertical, 6)

                Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

                Text(content.lead)
                    .font(.system(size: 15, design: .serif)).italic()
                    .foregroundColor(.quordleCoffee)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(content.rules) { rule in
                        HStack(alignment: .center, spacing: 13) {
                            Image(systemName: rule.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.quordlePrimary)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(Color.quordleBackground)
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.quordleCardBorder, lineWidth: 1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.text)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.quordlePrimaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(rule.sub)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.quordleSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 18)

                Button {
                    HapticManager.shared.buttonTap()
                    onDismiss()
                } label: {
                    Text("Got it").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 22)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.quordleCardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.quordleCardBorder, lineWidth: 1))
            )
            .padding(.horizontal, 20)
        }
    }
}
