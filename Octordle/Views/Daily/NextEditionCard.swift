import SwiftUI

/// Completed-page block naming the most recent unfinished past edition. Free inside
/// the free window (or Premium); otherwise one rewarded ad unlocks it right here.
struct NextEditionCard: View {
    let date: Date
    let editionNumber: Int
    let isLocked: Bool
    let isWorking: Bool
    let onPlay: () -> Void
    let onAllEditions: () -> Void

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }
    private var weekdayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Next edition")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(.quordlePrimary)
                Spacer()
                Button(action: onAllEditions) {
                    HStack(spacing: 3) {
                        Text("ALL EDITIONS")
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.quordleSecondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            Rectangle().fill(Color.quordlePrimaryText).frame(height: 1)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel)
                        .font(.system(size: 9.5, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(.quordleSecondaryText)
                    Text("No. \(editionNumber)")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(weekdayLabel)'s edition")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.quordlePrimaryText)
                    Text("You skipped this one")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundColor(.quordleSecondaryText)
                    tag
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)

            Rectangle().fill(Color.quordleCardBorder).frame(height: 1)

            Button(action: onPlay) {
                HStack(spacing: 9) {
                    if isWorking {
                        ProgressView().tint(.quordleBackgroundSecondary)
                    } else {
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                    }
                    Text(isLocked ? "Watch ad · Play No. \(editionNumber)" : "Play No. \(editionNumber)")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                }
                .foregroundColor(.quordleBackgroundSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 10).fill(isLocked ? Color.quordleOrange : Color.quordlePrimary))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isWorking)
            .padding(.top, 12)
        }
    }

    private var tag: some View {
        HStack(spacing: 4) {
            if isLocked { Image(systemName: "play.fill").font(.system(size: 7, weight: .bold)) }
            Text(isLocked ? "AD TO UNLOCK" : "FREE")
        }
        .font(.system(size: 9.5, weight: .heavy))
        .tracking(1.2)
        .foregroundColor(isLocked ? .quordleOrange : Color(red: 0.31, green: 0.49, blue: 0.23))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(isLocked ? Color.quordleOrange : Color(red: 0.31, green: 0.49, blue: 0.23), lineWidth: 1))
        .padding(.top, 4)
    }
}
