import SwiftUI

struct ATTPrePromptView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {} // swallow taps so content beneath isn't interactive

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Text("What is Allow Tracking?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 26)

                    Text("Rest assured, we never gather your personal information. By tapping 'Allow', you're letting us use anonymous data to show you ads that better suit your preferences. Choosing 'Ask App Not to Track' won't remove ads; they'll just be less relevant. We hope you enjoy playing Octordle!")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 0.5)

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.system(size: 17))
                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
            }
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
        }
    }
}
