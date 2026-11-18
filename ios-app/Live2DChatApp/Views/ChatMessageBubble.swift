import SwiftUI

public struct ChatMessageBubble: View {
    public let message: ChatMessage

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.sender == .user {
                Spacer(minLength: 40)
                userBubble
            } else if message.sender == .ai {
                aiBubble
                Spacer(minLength: 40)
            } else {
                Spacer()
                systemBubble
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.35, blue: 0.85), Color(red: 0.42, green: 0.25, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)

            Text(formatTime(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .padding(.trailing, 4)
        }
    }

    private var aiBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Emilia badge icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.78, green: 0.65, blue: 0.95), Color(red: 0.55, green: 0.40, blue: 0.80)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                if let name = message.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.75, blue: 1.0))
                        .padding(.leading, 4)
                }

                Text(message.text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.14, green: 0.12, blue: 0.24).opacity(0.78))
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.leading, 4)
            }
        }
    }

    private var systemBubble: some View {
        Text(message.text)
            .font(.system(size: 12, weight: .light))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
