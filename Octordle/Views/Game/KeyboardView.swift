import SwiftUI

/// Virtual keyboard view with dynamic key sizing
struct KeyboardView: View {
    let perBoardStates: [Character: KeyColorStates]
    let boardCount: Int
    let availableWidth: CGFloat
    let onKeyTap: (String) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    @EnvironmentObject var themeService: ThemeService
    @EnvironmentObject var subscriptionService: SubscriptionService

    private let rows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["ENTER", "Z", "X", "C", "V", "B", "N", "M", "⌫"]
    ]

    private let keySpacing: CGFloat = 5
    private let horizontalPadding: CGFloat = 4
    private let maxKeyboardWidth: CGFloat = 500

    private var theme: BoardTheme {
        themeService.effectiveTheme(isPremium: subscriptionService.isPremium)
    }

    /// Effective width capped for iPad
    private var effectiveWidth: CGFloat {
        min(availableWidth, maxKeyboardWidth)
    }

    /// Regular key width derived from row 1 (10 keys)
    private var regularKeyWidth: CGFloat {
        let totalSpacing = 9 * keySpacing + 2 * horizontalPadding
        return max(0, (effectiveWidth - totalSpacing) / 10)
    }

    /// ENTER key = 1.7× regular
    private var enterKeyWidth: CGFloat {
        regularKeyWidth * 1.7
    }

    /// Backspace key = 1.3× regular
    private var backspaceKeyWidth: CGFloat {
        regularKeyWidth * 1.3
    }

    private func keyWidth(for key: String) -> CGFloat {
        switch key {
        case "ENTER": return enterKeyWidth
        case "⌫": return backspaceKeyWidth
        default: return regularKeyWidth
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: keySpacing) {
                    ForEach(row, id: \.self) { key in
                        KeyButton(
                            key: key,
                            keyWidth: keyWidth(for: key),
                            colorStates: getKeyColorStates(key),
                            boardCount: boardCount,
                            theme: theme,
                            onTap: handleKeyTap
                        )
                    }
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: maxKeyboardWidth)
    }

    private func getKeyColorStates(_ key: String) -> KeyColorStates {
        guard key.count == 1, let char = key.first else {
            return .empty(boardCount: boardCount)
        }
        return perBoardStates[char] ?? .empty(boardCount: boardCount)
    }

    private func handleKeyTap(_ key: String) {
        switch key {
        case "ENTER":
            onSubmit()
        case "⌫":
            onDelete()
        default:
            onKeyTap(key)
        }
    }
}

/// Single keyboard key — uses raw gesture instead of Button for zero-delay response
struct KeyButton: View {
    let key: String
    let keyWidth: CGFloat
    let colorStates: KeyColorStates
    let boardCount: Int
    let theme: BoardTheme
    let onTap: (String) -> Void

    @State private var isPressed = false

    private var isSpecialKey: Bool {
        key == "ENTER" || key == "⌫"
    }

    private let keyHeight: CGFloat = 50
    private let cornerRadius: CGFloat = 4

    /// Font size scales with key width
    private var fontSize: CGFloat {
        if key == "⌫" { return min(18, keyWidth * 0.38) }
        if key == "ENTER" { return min(11, keyWidth * 0.18) }
        return min(16, keyWidth * 0.46)
    }

    var body: some View {
        Group {
            if key == "⌫" {
                Image(systemName: "delete.left.fill")
                    .font(.system(size: fontSize, weight: .semibold))
            } else {
                Text(key)
                    .font(.system(size: fontSize, weight: .bold))
            }
        }
        .foregroundColor(textColor)
        .frame(width: keyWidth, height: keyHeight)
        .background(keyBackground)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.easeOut(duration: 0.03), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                    onTap(key)
                }
        )
    }

    @ViewBuilder
    private var keyBackground: some View {
        if isSpecialKey || colorStates.isUniform {
            // Special keys or uniform state: single solid color
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colorStates.color(for: 0, theme: theme))
        } else {
            // Split rendering via Canvas
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let rrPath = RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)

                // Clip everything to the rounded rect shape
                context.clip(to: rrPath)

                if boardCount == 2 {
                    // Left/right halves
                    let midX = size.width / 2
                    context.fill(
                        Path(CGRect(x: 0, y: 0, width: midX, height: size.height)),
                        with: .color(colorStates.color(for: 0, theme: theme))
                    )
                    context.fill(
                        Path(CGRect(x: midX, y: 0, width: size.width - midX, height: size.height)),
                        with: .color(colorStates.color(for: 1, theme: theme))
                    )
                } else {
                    // 4 quadrants: TL=0, TR=1, BL=2, BR=3
                    let midX = size.width / 2
                    let midY = size.height / 2
                    let quadrants = [
                        CGRect(x: 0, y: 0, width: midX, height: midY),
                        CGRect(x: midX, y: 0, width: size.width - midX, height: midY),
                        CGRect(x: 0, y: midY, width: midX, height: size.height - midY),
                        CGRect(x: midX, y: midY, width: size.width - midX, height: size.height - midY)
                    ]
                    for (i, quadrant) in quadrants.enumerated() {
                        context.fill(
                            Path(quadrant),
                            with: .color(colorStates.color(for: i, theme: theme))
                        )
                    }
                }
            }
            .frame(width: keyWidth, height: keyHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    private var textColor: Color {
        let best = colorStates.bestState
        switch best {
        case .empty, .typing:
            return .quordlePrimaryText
        case .correct, .present, .absent:
            return .white
        }
    }
}

#Preview {
    GeometryReader { geo in
        KeyboardView(
            perBoardStates: [
                Character("A"): KeyColorStates(states: [.correct, .absent, .present, .empty]),
                Character("B"): KeyColorStates(states: [.present, .present, .absent, .correct]),
                Character("C"): KeyColorStates(states: [.absent, .absent, .absent, .absent])
            ],
            boardCount: 4,
            availableWidth: geo.size.width,
            onKeyTap: { _ in },
            onDelete: {},
            onSubmit: {}
        )
        .frame(maxWidth: .infinity)
    }
    .padding()
    .background(Color.quordleBackground)
    .environmentObject(ThemeService.shared)
    .environmentObject(SubscriptionService.shared)
}
