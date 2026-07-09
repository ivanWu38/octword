import SwiftUI

/// A selectable day in the archive calendar.
private struct ArchiveDay: Identifiable {
    let date: Date
    var id: String { GameState.dateString(for: date) }
}

/// Archive calendar — browse and play past daily puzzles.
struct ArchiveCalendarView: View {
    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared
    @ObservedObject private var rewardedAd = RewardedAdManager.shared

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: ArchiveDay?
    @State private var gameDate: Date?
    @State private var showGame = false
    @State private var showSubscription = false
    @State private var isUnlocking = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                freeBanner
                    .padding(.top, 8)

                monthNav
                    .padding(.top, 18)

                weekdayHeader
                    .padding(.top, 8)

                monthGrid
                    .padding(.top, 4)

                legend
                    .padding(.top, 20)

                progressLine
                    .padding(.top, 16)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            .iPadReadableWidth()
        }
        .background(LinearGradient.quordleBackground.ignoresSafeArea())
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            RewardedAdManager.shared.preloadIfNeeded()
            // Open on the month of the newest unplayed puzzle so its highlight is visible.
            if let latest = latestUnplayedDate {
                displayedMonth = calendar.startOfDay(for: latest)
            }
        }
        .sheet(item: $selectedDay) { day in
            ArchiveDaySheet(
                date: day.date,
                isUnlocking: $isUnlocking,
                onPlay: { startGame(on: day.date) },
                onWatchAd: { watchAdToUnlock(day.date) },
                onUpgrade: { presentSubscription() }
            )
            .environmentObject(themeService)
            .environmentObject(statsService)
            .environmentObject(subscriptionService)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .navigationDestination(isPresented: $showGame) {
            if let date = gameDate {
                GameView(archiveDate: date)
            }
        }
    }

    // MARK: - Free banner

    private var freeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 13))
                .foregroundColor(.quordlePrimary)
            Text("Last \(Constants.Archive.freeDays) days free. Unlock older puzzles with an ad or Premium.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.quordlePrimary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.quordlePrimary.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Month navigation

    private var monthNav: some View {
        HStack {
            navChevron(systemName: "chevron.left", enabled: canGoBack) {
                changeMonth(by: -1)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
            Spacer()
            navChevron(systemName: "chevron.right", enabled: canGoForward) {
                changeMonth(by: 1)
            }
        }
    }

    private func navChevron(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.quordleCardBackground)
                        .overlay(Circle().stroke(Color.quordleCardBorder, lineWidth: 1))
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.quordleSecondaryText.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(gridDates.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    dayCell(date)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let info = dayInfo(for: date)
        return Button {
            guard info.inRange else { return }
            HapticManager.shared.cardTap()
            selectedDay = ArchiveDay(date: date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(info.fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(info.borderColor, lineWidth: info.borderWidth)
                    )

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(info.textColor)

                    if info.locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(info.textColor.opacity(0.7))
                    } else if let dot = info.dotColor {
                        Circle().fill(dot).frame(width: 5, height: 5)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92))
        .disabled(!info.inRange)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color.quordleSuccess.opacity(0.5), label: "Solved")
            legendItem(color: Color.quordlePresent.opacity(0.5), label: "Played")
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.quordlePrimary, lineWidth: 2)
                    .frame(width: 14, height: 14)
                Text("Latest")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.quordleSecondaryText)
            }
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.quordleSecondaryText)
                Text("Locked")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.quordleSecondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.quordleSecondaryText)
        }
    }

    // MARK: - Progress line

    private var progressLine: some View {
        // Past puzzles only — today isn't part of the archive.
        let total = max(0, dailyPuzzleService.puzzleNumber - 1)
        let today = GameState.todayString()
        let played = dailyPuzzleService.completedDates.filter { $0 < today }.count
        return Text("\(played) of \(total) puzzles played")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(.quordleSecondaryText.opacity(0.7))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func startGame(on date: Date) {
        selectedDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            HapticManager.shared.gameStart()
            gameDate = date
            showGame = true
        }
    }

    private func watchAdToUnlock(_ date: Date) {
        isUnlocking = true
        Task {
            let earned = await RewardedAdManager.shared.showAd()
            isUnlocking = false
            guard earned else { return }
            dailyPuzzleService.unlockArchiveDate(date)
            startGame(on: date)
        }
    }

    private func presentSubscription() {
        selectedDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSubscription = true
        }
    }

    // MARK: - Month math

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }

    /// Dates laid out in a 7-column grid (nil = leading blank).
    private var gridDates: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        let leadingBlanks = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        let offset = (leadingBlanks + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(date)
            }
        }
        return cells
    }

    private var canGoBack: Bool {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        // Allow going back as long as the previous month still contains playable days
        let prevMonthEnd = endOfMonth(prev)
        return prevMonthEnd >= dailyPuzzleService.firstPuzzleDate
    }

    private var canGoForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return false }
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next
        return nextMonthStart <= dailyPuzzleService.todayStart
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }

    private func endOfMonth(_ date: Date) -> Date {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let range = calendar.range(of: .day, in: .month, for: monthStart),
              let end = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart) else {
            return date
        }
        return end
    }

    // MARK: - Day info

    /// The most recent archive day the player hasn't completed — highlighted to point
    /// them at the newest puzzle to try. nil if everything in range is done.
    private var latestUnplayedDate: Date? {
        var day = calendar.date(byAdding: .day, value: -1, to: dailyPuzzleService.todayStart)
        while let d = day, d >= dailyPuzzleService.firstPuzzleDate {
            if !dailyPuzzleService.isCompleted(d) { return d }
            day = calendar.date(byAdding: .day, value: -1, to: d)
        }
        return nil
    }

    private func dayInfo(for date: Date) -> DayCellInfo {
        let inRange = dailyPuzzleService.isInArchiveRange(date)
        // Today and beyond aren't playable in the archive (today lives on the Daily tab).
        let isFuture = calendar.startOfDay(for: date) >= dailyPuzzleService.todayStart
        let completed = dailyPuzzleService.isCompleted(date)
        let locked = dailyPuzzleService.isLocked(date, isPremium: subscriptionService.isPremium)
        let isLatest = latestUnplayedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false

        var won = false
        if completed,
           let result = statsService.loadCompletedDailyResult(for: dailyPuzzleService.dateString(for: date)) {
            won = result.isWon
        }

        return DayCellInfo(
            isLatest: isLatest,
            inRange: inRange,
            isFuture: isFuture,
            completed: completed,
            won: won,
            locked: locked
        )
    }
}

// MARK: - Day cell visual info

private struct DayCellInfo {
    let isLatest: Bool
    let inRange: Bool
    let isFuture: Bool
    let completed: Bool
    let won: Bool
    let locked: Bool

    var fillColor: Color {
        if !inRange { return .clear }
        if won { return Color.quordleSuccess.opacity(0.18) }
        if completed { return Color.quordlePresent.opacity(0.14) }
        if isLatest { return Color.quordlePrimary.opacity(0.12) }
        if locked { return Color.white.opacity(0.03) }
        return Color.white.opacity(0.05)
    }

    var borderColor: Color {
        if isLatest { return .quordlePrimary }
        if won { return Color.quordleSuccess.opacity(0.5) }
        if completed { return Color.quordlePresent.opacity(0.45) }
        return .clear
    }

    var borderWidth: CGFloat {
        isLatest ? 2 : 1
    }

    var textColor: Color {
        if isFuture || !inRange { return .quordleSecondaryText.opacity(0.25) }
        if locked { return .quordleSecondaryText }
        if won || completed || isLatest { return .quordlePrimaryText }
        return .quordleSecondaryText
    }

    var dotColor: Color? {
        if won { return .quordleSuccess }
        if completed { return .quordlePresent }
        return nil
    }
}

// MARK: - Day Sheet

private struct ArchiveDaySheet: View {
    let date: Date
    @Binding var isUnlocking: Bool
    let onPlay: () -> Void
    let onWatchAd: () -> Void
    let onUpgrade: () -> Void

    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @StateObject private var dailyPuzzleService = DailyPuzzleService.shared

    private var dayString: String { GameState.dateString(for: date) }
    private var completed: Bool { dailyPuzzleService.isCompleted(date) }
    private var locked: Bool { dailyPuzzleService.isLocked(date, isPremium: subscriptionService.isPremium) }
    private var puzzleNumber: Int { dailyPuzzleService.puzzleNumber(for: date) }

    private var longDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            if completed {
                completedContent
            } else if locked {
                lockedContent
            } else {
                playableContent
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.quordleBackground.ignoresSafeArea())
    }

    // MARK: Header pieces

    private func header(tag: String, tagColor: Color, centered: Bool = false) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: 6) {
            Text(tag.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(tagColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(tagColor.opacity(0.18)))

            Text("Puzzle #\(puzzleNumber)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
            Text(longDateString)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.quordleSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    // MARK: Playable

    private var playableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(tag: dailyPuzzleService.isFree(date) ? "Free · Last \(Constants.Archive.freeDays) Days" : "Unlocked",
                   tagColor: .quordleSuccess)

            HStack(spacing: 18) {
                Label("\(Constants.Game.boardCount) words", systemImage: "square.grid.2x2.fill")
                Label("\(Constants.Game.defaultDifficulty.maxGuesses) guesses", systemImage: "number")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.quordleSecondaryText)
            .padding(.top, 18)

            playButton(title: "Play", icon: "play.fill", action: onPlay)
                .padding(.top, 22)
        }
    }

    // MARK: Completed

    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(tag: "Completed", tagColor: .quordlePrimary)

            if let result = statsService.loadCompletedDailyResult(for: dayString) {
                resultCard(result)
                    .padding(.top, 18)
            }

            secondaryButton(title: "Play Again", icon: "arrow.clockwise", action: onPlay)
                .padding(.top, 18)
        }
    }

    private func resultCard(_ result: GameState) -> some View {
        let solved = result.boards.filter { $0.isSolved }.count
        let total = result.boards.count
        let timeString = String(format: "%d:%02d", result.elapsedSeconds / 60, result.elapsedSeconds % 60)

        return HStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Image(systemName: i < result.starRating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(i < result.starRating ? .quordleGold : .quordleSecondaryText.opacity(0.3))
                    }
                }
                Text("\(solved)/\(total)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)
            }

            Rectangle().fill(Color.quordleCardBorder).frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Result")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.quordlePrimaryText)
                HStack(spacing: 12) {
                    Label("\(result.guessCount) guesses", systemImage: "number")
                    Label(timeString, systemImage: "clock")
                }
                .font(.system(size: 13))
                .foregroundColor(.quordleSecondaryText)
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.quordleCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.quordleCardBorder, lineWidth: 1))
        )
    }

    // MARK: Locked

    private var lockedContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06)).frame(width: 60, height: 60)
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.quordleSecondaryText)
            }

            Text("Puzzle #\(puzzleNumber)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.quordlePrimaryText)
                .padding(.top, 12)
            Text(longDateString)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.quordleSecondaryText)
                .padding(.top, 3)

            // Watch ad
            Button(action: onWatchAd) {
                HStack(spacing: 10) {
                    if isUnlocking {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.rectangle.fill").font(.system(size: 18))
                    }
                    Text(isUnlocking ? "Loading…" : "Watch ad to unlock this day")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient.quordleButtonGradient))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isUnlocking)
            .padding(.top, 20)

            // or separator
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("or").font(.system(size: 11, weight: .semibold)).foregroundColor(.quordleSecondaryText.opacity(0.6))
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }
            .padding(.vertical, 14)

            // Premium box
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.quordleGold)
                    Text("Go Premium")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.quordleGold)
                }
                premiumPerk("Unlock all past puzzles")
                premiumPerk("Remove ads")
                premiumPerk("Exclusive themes")

                Button(action: onUpgrade) {
                    Text("Upgrade")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.quordleGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.quordleCardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.quordleGold.opacity(0.5), lineWidth: 1))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.quordleGold.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.quordleGold.opacity(0.3), lineWidth: 1))
            )
        }
    }

    private func premiumPerk(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.quordleSuccess)
            Text(text).font(.system(size: 12.5, weight: .medium)).foregroundColor(.quordleSecondaryText)
            Spacer()
        }
    }

    // MARK: Buttons

    private func playButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient.quordleButtonGradient))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.quordlePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.quordleCardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.quordlePrimary.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
