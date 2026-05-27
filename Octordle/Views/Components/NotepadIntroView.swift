import SwiftUI

/// One-time intro card for the notepad feature — editorial "Daily Edition" styling.
struct NotepadIntroView: View {
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                // Framed icon (newspaper engraving style)
                ZStack {
                    Rectangle().fill(Color.quordleCardBackground)
                    Rectangle().stroke(Color.quordlePrimaryText, lineWidth: 1.5)
                    Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1).padding(5)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 32))
                        .foregroundColor(.quordlePrimary)
                }
                .frame(width: 84, height: 84)

                VStack(spacing: 6) {
                    Text("New")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(.quordlePrimary)

                    Text("Notepad")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)

                    Text("Jot down your thoughts while playing. Tap the pencil icon anytime to open it.")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.quordleSecondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // "Look for this icon" row
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.quordlePrimary)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11))
                        .foregroundColor(.quordleSecondaryText.opacity(0.6))
                    Text("Look for this icon")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(.quordleSecondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1))

                Button { dismiss() } label: {
                    Text("Got it")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 2)
            }
            .padding(26)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.quordleBackground)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.quordleCardBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 28, y: 14)
            )
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = true }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
    }
}
