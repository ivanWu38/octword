import SwiftUI

/// Mark of Distinction detail — an editorial "clipping" card (matches the design mock).
struct AchievementDetailView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: (current: Int, required: Int)
    let onDismiss: () -> Void

    @State private var appeared = false

    private var progressFraction: CGFloat {
        guard progress.required > 0 else { return 0 }
        return CGFloat(progress.current) / CGFloat(progress.required)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 18) {
                // Framed icon (newspaper engraving style)
                ZStack {
                    Rectangle().fill(Color.quordleCardBackground)
                    Rectangle().stroke(Color.quordlePrimaryText, lineWidth: 1.5)
                    Rectangle().stroke(Color.quordleCardBorder, lineWidth: 1).padding(5)
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 34))
                        .foregroundColor(isUnlocked ? .quordlePrimary : .quordleSecondaryText.opacity(0.5))
                }
                .frame(width: 88, height: 88)

                VStack(spacing: 6) {
                    Text(achievement.title)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.quordleSecondaryText)
                        .multilineTextAlignment(.center)
                }

                if isUnlocked {
                    Text("— Earned —")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(.quordlePrimary)
                        .padding(.top, 2)
                } else {
                    VStack(spacing: 10) {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.quordleCardBorder)
                                Capsule().fill(Color.quordlePrimary)
                                    .frame(width: g.size.width * progressFraction)
                            }
                        }
                        .frame(height: 5)

                        Text("\(progress.current) of \(progress.required)  ·  \(max(0, progress.required - progress.current)) to go")
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(.quordleSecondaryText)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(28)
            .frame(width: 260)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.quordleBackground)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.quordleCardBorder, lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 28, y: 14)
            )
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .onTapGesture { dismiss() }
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
