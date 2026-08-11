import SwiftUI
import GameKit

/// Today's ranked standings (Game Center backed), styled as a newspaper league table.
///
/// Deliberately never shows "you're #12 **of 26**" — the denominator is the weakest
/// number this board has while the app is young, and quoting it makes a decent rank
/// read as a small one. The total appears only in the footer, and only once the board
/// is busy (see `GameCenterService.minPlayersToShowTotal`).
struct DailyRankView: View {
    @ObservedObject private var gameCenter = GameCenterService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var localEntry: GKLeaderboard.Entry?
    @State private var entries: [GKLeaderboard.Entry] = []
    @State private var totalPlayers = 0
    @State private var isLoading = true

    private let maxGuesses = Constants.Game.defaultDifficulty.maxGuesses
    private let boardCount = Constants.Game.defaultDifficulty.boardCount

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.quordleBackground.ignoresSafeArea())
        .task { await load() }
        .onChange(of: gameCenter.isAuthenticated) { authed in
            if authed { Task { await load() } }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Edition · Ranked")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundColor(.quordleSecondaryText)
                    Text("Daily Rank")
                        .font(.system(size: 27, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                }

                Spacer()

                Button {
                    HapticManager.shared.backTap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.quordleSecondaryText)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.quordleCardBackground))
                        .overlay(Circle().stroke(Color.quordleCardBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !gameCenter.isAuthenticated {
            signInCTA
        } else if isLoading {
            VStack {
                Spacer()
                ProgressView().tint(.quordlePrimary)
                Spacer()
            }
        } else if entries.isEmpty {
            stateMessage(
                symbol: "✦",
                title: "No one has filed yet",
                detail: "Be the first to finish today's edition and top the page."
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let localEntry {
                        groupLabel("Your position")
                        row(for: localEntry, highlighted: true)
                    }

                    groupLabel("Leaders")
                    columnHeader
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        row(for: entry, highlighted: isLocal(entry))
                    }

                    footer
                }
                .padding(.bottom, 24)
            }
        }
    }

    /// The board's own state, told honestly: quiet boards get an explanation
    /// ("it fills through the day"), busy boards get the actual count.
    private var footer: some View {
        Group {
            if totalPlayers >= GameCenterService.minPlayersToShowTotal {
                Text("\(totalPlayers) readers have filed today")
            } else {
                Text("The board fills through the day.\nCome back later to see where you settled.")
            }
        }
        .font(.system(size: 13, design: .serif))
        .italic()
        .foregroundColor(.quordleSecondaryText)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(.quordleSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Rank").frame(width: 34, alignment: .leading)
            Text("Reader").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 36)
            Text("Solved").frame(width: 38, alignment: .trailing)
            Text("Guess").frame(width: 40, alignment: .trailing)
            Text("Time").frame(width: 46, alignment: .trailing)
        }
        .font(.system(size: 8.5, weight: .semibold))
        .tracking(1.4)
        .textCase(.uppercase)
        .foregroundColor(.quordleSecondaryText)
        .padding(.horizontal, 18)
        .padding(.bottom, 7)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)
        }
    }

    // MARK: - Sign-in CTA (not authenticated)

    private var signInCTA: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("✦")
                .font(.system(size: 26))
                .foregroundColor(.quordlePrimary)
                .frame(width: 64, height: 64)
                .overlay(Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1.5))

            Text("Join today's ranking")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)

            Text("Sign in to Game Center to see where you place among everyone who filed today's edition.")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 34)

            Button {
                HapticManager.shared.primaryTap()
                gameCenter.authenticate()
            } label: {
                Text("Sign in to Game Center").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 34)
            .padding(.top, 4)

            Text("If nothing happens, enable Game Center in the Settings app.")
                .font(.system(size: 11, design: .serif))
                .foregroundColor(.quordleSecondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private func stateMessage(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(symbol)
                .font(.system(size: 26))
                .foregroundColor(.quordlePrimary)
                .frame(width: 64, height: 64)
                .overlay(Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1.5))
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
            Text(detail)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.quordleSecondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 38)
            Spacer()
            Spacer()
        }
    }

    // MARK: - Row

    private func row(for entry: GKLeaderboard.Entry, highlighted: Bool) -> some View {
        let decoded = GameCenterService.decodeScore(entry.score, maxGuesses: maxGuesses)
        return HStack(spacing: 0) {
            Text("\(entry.rank)")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(rankColor(entry.rank))
                .frame(width: 34, alignment: .leading)

            PlayerAvatar(player: entry.player)
                .padding(.trailing, 10)

            Text(entry.player.displayName)
                .font(.system(size: 13.5, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(decoded.solvedBoards)/\(boardCount)")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(.quordlePrimaryText)
                .frame(width: 38, alignment: .trailing)

            Text("\(decoded.guessCount)")
                .font(.system(size: 11.5))
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 40, alignment: .trailing)

            Text(timeString(decoded.elapsedSeconds))
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundColor(.quordleSecondaryText)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(highlighted ? Color.quordlePrimary.opacity(0.07) : Color.clear)
        .overlay(alignment: .leading) {
            if highlighted {
                Rectangle().fill(Color.quordlePrimary).frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .quordleGold
        case 2, 3: return .quordleOrange
        default: return .quordlePrimaryText
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func isLocal(_ entry: GKLeaderboard.Entry) -> Bool {
        entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        if let result = await gameCenter.loadDailyEntries(top: 50) {
            localEntry = result.local
            entries = result.entries
            totalPlayers = result.total
        }
        isLoading = false
    }
}

/// Async-loading Game Center player avatar with initials fallback.
private struct PlayerAvatar: View {
    let player: GKPlayer
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.quordlePrimary
                Text(initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(Circle())
        .task {
            image = try? await player.loadPhoto(for: .small)
        }
    }

    private var initials: String {
        let parts = player.displayName.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }
        return String(chars).uppercased()
    }
}
