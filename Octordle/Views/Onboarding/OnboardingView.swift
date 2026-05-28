import SwiftUI

/// Onboarding view for new users
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    @Environment(\.colorScheme) private var colorScheme

    private let totalPages = 5

    var body: some View {
        ZStack {
            LinearGradient.quordleBackground
                .ignoresSafeArea()

            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        hasSeenOnboarding = true
                    }
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }

                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    WelcomePage()
                        .tag(0)

                    // Page 2: How to Play
                    HowToPlayPage()
                        .tag(1)

                    // Page 3: Color Hints
                    ColorHintsPage()
                        .tag(2)

                    // Page 4: Daily Challenge
                    DailyChallengePage()
                        .tag(3)

                    // Page 5: Get Started
                    GetStartedPage()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Bottom buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Get Started") {
                            hasSeenOnboarding = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    /// Dynamically get the app icon from the bundle so it always matches the real icon
    private var appIconImage: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconName = iconFiles.last {
            return UIImage(named: iconName)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon (auto-syncs with actual app icon)
            if let uiImage = appIconImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            VStack(spacing: 16) {
                Text("Welcome to Octordle")
                    .font(.title.bold())
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)

                Text("Guess eight 5-letter words at the same time! Test your vocabulary skills with this focused Octordle puzzle game.")
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("You can always revisit this in Settings.")
                    .font(.footnote)
                    .foregroundColor(.quordleSecondaryText.opacity(0.7))
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: How to Play

private struct HowToPlayPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient.quordleAccentGradient)

            VStack(spacing: 16) {
                Text("How to Play")
                    .font(.title.bold())
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)

                Text("Type a 5-letter word and press Enter. Your guess applies to all eight boards at once. You have 13 attempts to solve every word!")
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Visual: eight mini grids
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { col in
                            MiniGridPreview(seed: row * 4 + col)
                        }
                    }
                }
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 3: Color Hints

private struct ColorHintsPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "paintpalette.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient.quordleAccentGradient)

            VStack(spacing: 16) {
                Text("Color Hints")
                    .font(.title.bold())
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)

                Text("After each guess, tiles change color to show how close you are:")
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Visual examples
            VStack(spacing: 16) {
                // Correct example
                HStack(spacing: 12) {
                    ExampleTile(letter: "A", state: .correct)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terracotta")
                            .font(.headline)
                            .foregroundColor(.quordleCorrect)
                        Text("Correct letter, correct position")
                            .font(.caption)
                            .foregroundColor(.quordleSecondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)

                // Present example
                HStack(spacing: 12) {
                    ExampleTile(letter: "B", state: .present)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gold")
                            .font(.headline)
                            .foregroundColor(.quordlePresent)
                        Text("Correct letter, wrong position")
                            .font(.caption)
                            .foregroundColor(.quordleSecondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)

                // Absent example
                HStack(spacing: 12) {
                    ExampleTile(letter: "C", state: .absent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gray")
                            .font(.headline)
                            .foregroundColor(.quordleAbsent)
                        Text("Letter not in the word")
                            .font(.caption)
                            .foregroundColor(.quordleSecondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 4: Daily Challenge

private struct DailyChallengePage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.quordleGold)

            VStack(spacing: 16) {
                Text("Daily Challenge")
                    .font(.title.bold())
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)

                Text("Play a new puzzle every day! The same puzzle is shared worldwide, so you can compare with friends. Build your streak by playing daily!")
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Streak preview
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(.quordleOrange)
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.quordleSecondaryText)
                }

                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.title)
                        .foregroundColor(.quordleGold)
                    Text("Best")
                        .font(.caption)
                        .foregroundColor(.quordleSecondaryText)
                }

                VStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                        .foregroundColor(.quordlePrimary)
                    Text("Stats")
                        .font(.caption)
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 5: Get Started

private struct GetStartedPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.quordleSuccess)

            VStack(spacing: 16) {
                Text("Ready to Play!")
                    .font(.title.bold())
                    .foregroundColor(.quordlePrimaryText)
                    .multilineTextAlignment(.center)

                Text("You're all set! Solve today's puzzle and track your progress. Good luck!")
                    .font(.body)
                    .foregroundColor(.quordleSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Mode preview
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundColor(.quordleGold)
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.quordleSecondaryText)
                }

                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.quordleSecondary)
                    Text("Journey")
                        .font(.caption)
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Supporting Views

/// Example tile for color hints page
private struct ExampleTile: View {
    let letter: String
    let state: TileState

    enum TileState {
        case correct, present, absent
    }

    var backgroundColor: Color {
        switch state {
        case .correct: return .quordleCorrect
        case .present: return .quordlePresent
        case .absent: return .quordleAbsent
        }
    }

    var body: some View {
        Text(letter)
            .font(.title2.bold())
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
    }
}

/// Mini grid preview for how to play page
private struct MiniGridPreview: View {
    let seed: Int

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(randomColor(row: row, col: col))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }

    private func randomColor(row: Int, col: Int) -> Color {
        let colors: [Color] = [.quordleCorrect, .quordlePresent, .quordleAbsent, .quordleTileEmpty]
        let index = (row * 5 + col + seed) % colors.count
        return colors[index]
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
