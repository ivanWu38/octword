import SwiftUI

/// Pulse cursor overlay using a simple repeating opacity animation
private struct PulseCursorOverlay: View {
    let color: Color
    let lineWidth: CGFloat

    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(color, lineWidth: lineWidth)
            .opacity(pulse ? 1.0 : 0.3)
            .animation(
                .easeInOut(duration: Constants.Animation.cursorPulseDuration)
                .repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}

/// Single tile view with color feedback
struct TileView: View {
    let tile: TileData
    let size: CGFloat
    let columnIndex: Int
    let shouldAnimate: Bool
    let isCurrentRow: Bool
    let shouldPulse: Bool

    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService

    @State private var scale: CGFloat = 1.0

    private var theme: BoardTheme {
        themeService.effectiveTheme(isPremium: subscriptionService.isPremium)
    }

    private var isRevealed: Bool {
        tile.state == .correct || tile.state == .present || tile.state == .absent
    }

    var body: some View {
        ZStack {
            // Background with color
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor)

            // Border (static; skip on pulsing tile — pulse overlay handles it)
            if !isRevealed && !shouldPulse {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: borderWidth)
            }

            // Pulse cursor overlay (only on first empty tile of current row)
            if shouldPulse {
                PulseCursorOverlay(
                    color: theme.currentRowBorderColor,
                    lineWidth: Constants.Layout.currentRowBorderWidth
                )
            }

            // Letter
            Text(tile.letter)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundColor(textColor)
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .onChange(of: tile.letter) { newValue in
            // Bounce animation when typing
            if !newValue.isEmpty && tile.state == .typing {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    scale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }
            }
        }
    }

    private var backgroundColor: Color {
        switch tile.state {
        case .empty, .typing:
            return theme.emptyColor
        case .correct:
            return theme.correctColor
        case .present:
            return theme.presentColor
        case .absent:
            return theme.absentColor
        }
    }

    private var borderColor: Color {
        switch tile.state {
        case .empty:
            return isCurrentRow ? theme.currentRowBorderColor : theme.emptyBorderColor
        case .typing:
            return theme.typingBorderColor
        default:
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch tile.state {
        case .typing:
            return 2
        case .empty where isCurrentRow:
            return Constants.Layout.currentRowBorderWidth
        case .empty:
            return 1
        default:
            return 0
        }
    }

    private var textColor: Color {
        if isRevealed {
            return .white
        } else {
            return .quordlePrimaryText
        }
    }
}

#Preview {
    HStack {
        TileView(tile: TileData(letter: "", state: .empty), size: 50, columnIndex: 0,
                 shouldAnimate: false, isCurrentRow: true, shouldPulse: true)
        TileView(tile: TileData(letter: "", state: .empty), size: 50, columnIndex: 1,
                 shouldAnimate: false, isCurrentRow: true, shouldPulse: false)
        TileView(tile: TileData(letter: "C", state: .correct), size: 50, columnIndex: 2,
                 shouldAnimate: false, isCurrentRow: false, shouldPulse: false)
        TileView(tile: TileData(letter: "D", state: .present), size: 50, columnIndex: 3,
                 shouldAnimate: false, isCurrentRow: false, shouldPulse: false)
        TileView(tile: TileData(letter: "E", state: .absent), size: 50, columnIndex: 4,
                 shouldAnimate: false, isCurrentRow: false, shouldPulse: false)
    }
    .padding()
    .background(Color.quordleBackground)
    .environmentObject(ThemeService.shared)
    .environmentObject(SubscriptionService.shared)
}
