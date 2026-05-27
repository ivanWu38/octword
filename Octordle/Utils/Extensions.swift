import SwiftUI
import UIKit

// MARK: - Color Extensions
//
// "The Daily Edition" palette — paper, ink, and terracotta. Warm editorial tones
// that avoid both the green/yellow of Wordle-clones and the blue/purple of Quordle.
// Every value has a light (paper) and dark (night edition) variant.

private func dynamicColor(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    Color(UIColor { tc in
        let c = tc.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

extension Color {
    // MARK: - Accent (terracotta)

    /// Primary accent — terracotta (rust).
    static let quordlePrimary = dynamicColor(light: (0.682, 0.255, 0.141), dark: (0.824, 0.337, 0.173))

    /// Secondary accent — deeper rust (used where a second tone is needed).
    static let quordleSecondary = dynamicColor(light: (0.561, 0.200, 0.082), dark: (0.690, 0.271, 0.122))

    // MARK: - Game Hint Colors (red / amber / grey — clearly distinct in both modes)

    /// Correct position — rust red.
    static let quordleCorrect = dynamicColor(light: (0.682, 0.255, 0.141), dark: (0.824, 0.337, 0.173))

    /// Present but wrong position — amber gold.
    static let quordlePresent = dynamicColor(light: (0.890, 0.647, 0.184), dark: (0.925, 0.698, 0.243))

    /// Absent letter — neutral warm grey.
    static let quordleAbsent = dynamicColor(light: (0.655, 0.627, 0.553), dark: (0.329, 0.298, 0.247))

    // MARK: - Backgrounds (paper / night)

    static let quordleBackground = dynamicColor(light: (0.957, 0.941, 0.902), dark: (0.090, 0.075, 0.055))
    static let quordleBackgroundSecondary = dynamicColor(light: (0.984, 0.973, 0.945), dark: (0.141, 0.122, 0.090))
    static let quordleBackgroundStart = dynamicColor(light: (0.957, 0.941, 0.902), dark: (0.090, 0.075, 0.055))
    static let quordleBackgroundEnd = dynamicColor(light: (0.957, 0.941, 0.902), dark: (0.090, 0.075, 0.055))

    // MARK: - Cards

    static let quordleCardBackground = dynamicColor(light: (0.984, 0.973, 0.945), dark: (0.141, 0.122, 0.090))
    static let quordleCardBorder = dynamicColor(light: (0.847, 0.816, 0.749), dark: (0.235, 0.204, 0.165))

    // MARK: - Text (ink)

    static let quordlePrimaryText = dynamicColor(light: (0.149, 0.133, 0.110), dark: (0.929, 0.898, 0.831))
    static let quordleSecondaryText = dynamicColor(light: (0.541, 0.510, 0.459), dark: (0.604, 0.561, 0.486))

    // MARK: - Tiles

    static let quordleTileEmpty = dynamicColor(light: (0.984, 0.973, 0.945), dark: (0.141, 0.122, 0.090))
    static let quordleTileBorder = dynamicColor(light: (0.847, 0.816, 0.749), dark: (0.235, 0.204, 0.165))
    static let quordleTileTypingBorder = dynamicColor(light: (0.722, 0.682, 0.592), dark: (0.353, 0.318, 0.259))

    // MARK: - Keyboard

    static let quordleKeyBackground = dynamicColor(light: (0.918, 0.890, 0.827), dark: (0.196, 0.173, 0.141))

    // MARK: - Tab Bar

    static let quordleTabBarBackground = dynamicColor(light: (0.957, 0.941, 0.902), dark: (0.075, 0.063, 0.047))
    static let quordleTabInactive = dynamicColor(light: (0.620, 0.588, 0.533), dark: (0.502, 0.467, 0.404))

    // MARK: - Accent extras

    /// Gold for stars / achievements (amber, matches "present").
    static let quordleGold = dynamicColor(light: (0.847, 0.612, 0.157), dark: (0.925, 0.698, 0.243))

    /// Orange for streaks / the flame animation.
    static let quordleOrange = dynamicColor(light: (0.847, 0.412, 0.169), dark: (0.886, 0.451, 0.196))

    /// Success (checkmarks, confirmations) — uses the terracotta accent to stay on-brand.
    static let quordleSuccess = dynamicColor(light: (0.682, 0.255, 0.141), dark: (0.824, 0.337, 0.173))
}

// MARK: - LinearGradient Extensions
//
// The editorial look is flat — these "gradients" are intentionally single-tone so any
// existing call sites render as clean solid fills instead of the old blue→purple wash.

extension LinearGradient {
    static let quordleBackground = LinearGradient(
        colors: [.quordleBackground, .quordleBackground],
        startPoint: .top, endPoint: .bottom
    )

    static let quordleButtonGradient = LinearGradient(
        colors: [.quordlePrimary, .quordlePrimary],
        startPoint: .leading, endPoint: .trailing
    )

    static let quordleAccentGradient = LinearGradient(
        colors: [.quordlePrimary, .quordlePrimary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - View Extensions

extension View {
    /// Flat editorial card (replaces the old translucent "glass" look).
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.quordleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.quordleCardBorder, lineWidth: 1)
                )
        )
    }

    /// Card style with hairline border.
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

    /// Flat background.
    func quordleGradientBackground() -> some View {
        self.background(Color.quordleBackground.ignoresSafeArea())
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

/// Primary button — flat terracotta with a small corner radius (editorial, not pill).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .serif))
            .foregroundColor(Color(UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 0.984, green: 0.953, blue: 0.902, alpha: 1)
                    : UIColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1)
            }))
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.quordlePrimary))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button — hairline outline.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .serif))
            .foregroundColor(.quordlePrimaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.quordleCardBackground))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.quordleCardBorder, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
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
