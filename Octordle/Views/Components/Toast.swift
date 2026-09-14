import SwiftUI

/// Small message near the bottom of the screen; clears itself after `duration`.
struct ToastModifier: ViewModifier {
    @Binding var text: String?
    var duration: TimeInterval = 2.2

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let text {
                    Text(text)
                        .font(.system(size: 13.5, weight: .semibold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.quordleCardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.quordleCardBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                        )
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation { if self.text == text { self.text = nil } }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: text)
    }
}

extension View {
    func toast(_ text: Binding<String?>, duration: TimeInterval = 2.2) -> some View {
        modifier(ToastModifier(text: text, duration: duration))
    }
}

/// Shared copy for the rewarded-ad "no fill" case.
enum AdCopy {
    static let notReady = "Ad not ready yet — try again in a moment"
}
