import SwiftUI

/// Challenge preset list — editorial "Daily Edition" styling, grouped by family.
/// Tapping a preset pushes `ChallengeGameView`, which owns the session and hosts
/// consecutive Unlimited-style rounds until the clock/lives run out.
struct ChallengesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: ChallengeType?
    @State private var showGame = false
    /// Bumped whenever a session ends, so best-score labels refresh without
    /// needing a full ObservableObject wired through this list.
    @State private var bestScoreRefresh = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header

                sectionLabel("Timed")
                VStack(spacing: 12) {
                    ForEach(ChallengeType.timedPresets) { preset in
                        presetRow(preset)
                    }
                }
                .padding(.horizontal, 24)

                sectionLabel("Run")
                VStack(spacing: 12) {
                    ForEach(ChallengeType.runPresets) { preset in
                        presetRow(preset)
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 110)
            }
            .iPadReadableWidth(520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.quordleBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showGame) {
            if let preset = selectedPreset {
                ChallengeGameView(preset: preset)
            }
        }
        .onChange(of: showGame) { isShowing in
            // Refreshes best-score labels once the player returns from a session.
            if !isShowing { bestScoreRefresh += 1 }
        }
    }

    // MARK: - Header

    private var header: some View {
        EditorialMasthead(
            kicker: "Beyond the Daily",
            title: "Challenges",
            subtitle: "Timed · Run",
            onBack: { dismiss() }
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundColor(.quordleSecondaryText)
            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 14)
    }

    // MARK: - Rows

    private func presetRow(_ preset: ChallengeType) -> some View {
        let best = ChallengeSession.loadBest(for: preset.id)

        return Button {
            HapticManager.shared.buttonTap()
            selectedPreset = preset
            showGame = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: preset.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.quordlePrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text(preset.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.quordleSecondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(best > 0 ? "Best \(best)" : "—")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(best > 0 ? .quordleGold : .quordleSecondaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.quordleCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.quordleCardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
        .id("\(preset.id)-\(bestScoreRefresh)")
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
