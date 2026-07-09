import SwiftUI

struct ReviewPromptView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Rate Octordle")
                .font(.title.bold())
                .foregroundColor(.quordlePrimaryText)

            Text("We're so glad you're having fun with Octordle! Would you mind taking a moment to leave us a 5-star review? It really helps us continue making the game better.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.quordleSecondaryText)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    HapticManager.shared.primaryTap()
                    AnalyticsService.logReviewPromptResponse(accepted: true)
                    onAccept()
                } label: {
                    Text("OK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.quordleCorrect)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    HapticManager.shared.backTap()
                    AnalyticsService.logReviewPromptResponse(accepted: false)
                    onDecline()
                } label: {
                    Text("Later")
                        .font(.subheadline)
                        .foregroundColor(.quordleSecondaryText)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            AnalyticsService.logReviewPromptShown()
        }
    }
}
