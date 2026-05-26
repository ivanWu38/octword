import SwiftUI

/// Confetti celebration animation
struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false

    let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        .quordleCorrect, .quordlePresent, .quordleGold
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece, animate: animate, maxY: geometry.size.height + 50)
                }
            }
            .onAppear {
                createPieces(in: geometry.size)
                withAnimation(.easeIn(duration: Constants.Animation.confettiDuration)) {
                    animate = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func createPieces(in size: CGSize) {
        pieces = (0..<50).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...0),
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .yellow,
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle
            )
        }
    }
}

/// Single confetti piece
struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let color: Color
    let shape: ConfettiShape
}

/// Confetti shapes
enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case triangle
}

/// View for a single confetti piece
struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let animate: Bool
    let maxY: CGFloat

    var body: some View {
        Group {
            switch piece.shape {
            case .rectangle:
                Rectangle()
                    .fill(piece.color)
            case .circle:
                Circle()
                    .fill(piece.color)
            case .triangle:
                Triangle()
                    .fill(piece.color)
            }
        }
        .frame(width: 10, height: 10)
        .rotationEffect(.degrees(piece.rotation + (animate ? 360 : 0)))
        .position(x: piece.x, y: animate ? maxY : piece.y)
        .opacity(animate ? 0 : 1)
    }
}

/// Triangle shape for confetti
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiView()
    }
}
