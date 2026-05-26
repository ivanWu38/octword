import SwiftUI
import UIKit

// MARK: - Color Extensions

extension Color {
    // MARK: - Primary Colors (Blue-Purple Theme)

    /// Primary accent color - soft blue
    static let quordlePrimary = Color(red: 0.4, green: 0.5, blue: 1.0)

    /// Secondary accent color - purple
    static let quordleSecondary = Color(red: 0.6, green: 0.4, blue: 1.0)

    // MARK: - Game Hint Colors (Replaces Green/Yellow)

    /// Correct position - Cornflower blue #6495ED
    static let quordleCorrect = Color(red: 0.39, green: 0.58, blue: 0.93)

    /// Present but wrong position - Amber gold #D9A640
    static let quordlePresent = Color(red: 0.85, green: 0.65, blue: 0.25)

    /// Absent letter
    static let quordleAbsent = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.23, green: 0.24, blue: 0.25, alpha: 1) // #3A3B3C
            : UIColor(red: 0.47, green: 0.49, blue: 0.51, alpha: 1) // #787C7E
    })

    // MARK: - Background Colors (Warm Tones)

    /// Main background - cream/dark blue-black
    static let quordleBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    })

    /// Secondary background
    static let quordleBackgroundSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1)
            : UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1)
    })

    /// Gradient start color
    static let quordleBackgroundStart = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    })

    /// Gradient end color
    static let quordleBackgroundEnd = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 1)
            : UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1)
    })

    // MARK: - Card Colors

    /// Card background - ivory white / semi-transparent
    static let quordleCardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
    })

    /// Card border - warm tones
    static let quordleCardBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.15)
            : UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1)
    })

    // MARK: - Text Colors

    static let quordlePrimaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
    })

    static let quordleSecondaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.7, alpha: 1)
            : UIColor(white: 0.4, alpha: 1)
    })

    // MARK: - Tile Colors

    static let quordleTileEmpty = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 1)
            : UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
    })

    static let quordleTileBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.25, blue: 0.30, alpha: 1)
            : UIColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1)
    })

    static let quordleTileTypingBorder = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1)
            : UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1)
    })

    // MARK: - Keyboard Colors

    static let quordleKeyBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.35, blue: 0.42, alpha: 1)
            : UIColor(red: 0.85, green: 0.83, blue: 0.80, alpha: 1)
    })

    // MARK: - Tab Bar Colors

    static let quordleTabBarBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.10, alpha: 1.0)
            : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)
    })

    static let quordleTabInactive = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.45, alpha: 1)
            : UIColor(white: 0.55, alpha: 1)
    })

    // MARK: - Accent Colors

    /// Gold color for achievements/stars
    static let quordleGold = Color(red: 1.0, green: 0.8, blue: 0.3)

    /// Orange for streaks/fire
    static let quordleOrange = Color(red: 1.0, green: 0.6, blue: 0.2)

    /// Success green (for non-hint use)
    static let quordleSuccess = Color(red: 0.3, green: 0.75, blue: 0.45)
}

// MARK: - LinearGradient Extensions

extension LinearGradient {
    /// Main background gradient
    static let quordleBackground = LinearGradient(
        colors: [.quordleBackgroundStart, .quordleBackgroundEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Button gradient (blue to purple)
    static let quordleButtonGradient = LinearGradient(
        colors: [.quordlePrimary, .quordleSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Accent gradient
    static let quordleAccentGradient = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.55, blue: 1.0),
            Color(red: 0.65, green: 0.45, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Extensions

extension View {
    /// Glass background effect
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// Card style with warm border
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.quordleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.quordleCardBorder, lineWidth: 1)
        )
    }

    /// Gradient background
    func quordleGradientBackground() -> some View {
        self.background(LinearGradient.quordleBackground.ignoresSafeArea())
    }

    /// Shake animation modifier
    func shake(isShaking: Bool) -> some View {
        self.modifier(ShakeModifier(isShaking: isShaking))
    }
}

// MARK: - Button Styles

/// Scale button style with press effect
struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat

    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Primary button style with gradient
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.quordleButtonGradient)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.quordlePrimaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.quordleCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.quordleCardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - iPad Content Width Modifier

struct iPadContentWidth: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Constrain content width on iPad, centered. No effect on iPhone.
    func iPadReadableWidth(_ maxWidth: CGFloat = 600) -> some View {
        modifier(iPadContentWidth(maxWidth: maxWidth))
    }
}

// MARK: - Shake Modifier

struct ShakeModifier: ViewModifier {
    let isShaking: Bool
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: isShaking) { newValue in
                if newValue {
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                        shakeOffset = -10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                            shakeOffset = 10
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                            shakeOffset = -5
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                            shakeOffset = 0
                        }
                    }
                }
            }
    }
}

// MARK: - String Extensions

extension String {
    var isValidWord: Bool {
        count == 5 && allSatisfy { $0.isLetter }
    }
}

// MARK: - Daily Reset (UTC) Helpers

extension Calendar {
    /// Gregorian calendar fixed to UTC. All daily-puzzle date math uses this so
    /// the puzzle (and the Game Center leaderboard) rolls over at the same instant
    /// — 00:00 UTC — for every player worldwide, instead of each device's local midnight.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

extension DateFormatter {
    /// "yyyy-MM-dd" formatter in UTC — the canonical daily-puzzle date key.
    static let utcDayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
