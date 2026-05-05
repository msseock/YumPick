import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isMine: Bool
    let status: ChatMessageStatus
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 48) }

            if !isMine {
                CachedImage(path: message.sender.profileImage)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(message.sender.nick)
                        .ypFont(YPFont.caption1)
                        .foregroundStyle(YPColor.textSecondary)
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .ypFont(YPFont.body2)
                        .foregroundStyle(isMine ? YPColor.gray0 : YPColor.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(status == .sending ? 0.6 : 1.0)
                }

                ForEach(message.files, id: \.self) { path in
                    CachedImage(path: path)
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(status == .sending ? 0.6 : 1.0)
                }

                if status == .failed {
                    Button(action: onRetry) {
                        Label("전송 실패 · 다시 시도", systemImage: "exclamationmark.circle")
                            .ypFont(YPFont.caption1)
                            .foregroundStyle(YPColor.semanticDanger)
                    }
                    .buttonStyle(.plain)
                }

                timeLabel
            }
            .frame(maxWidth: 260, alignment: isMine ? .trailing : .leading)

            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var bubbleBackground: Color {
        isMine ? YPColor.actionPrimary : YPColor.backgroundSecondary
    }

    private var timeLabel: some View {
        Group {
            if let date = DateFormatManager.shared.date(fromChatISOString: message.createdAt) {
                Text(DateFormatManager.shared.chatTime(from: date))
                    .ypFont(YPFont.caption2)
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
    }
}

#Preview("ChatBubbleView") {
    VStack(spacing: 16) {
        ChatBubbleView(
            message: ChatMessage(
                chatID: "preview-1",
                roomID: "room-preview",
                content: "오늘 픽업 시간 10분만 늦춰도 괜찮을까요?",
                createdAt: DateFormatManager.shared.chatISOString(from: Date()),
                updatedAt: DateFormatManager.shared.chatISOString(from: Date()),
                sender: ChatSender(userID: "seller", nick: "얌픽가게", profileImage: nil),
                files: []
            ),
            isMine: false,
            status: .sent
        ) {}

        ChatBubbleView(
            message: ChatMessage(
                chatID: "preview-2",
                roomID: "room-preview",
                content: "네 괜찮아요. 도착하면 바로 말씀드릴게요.",
                createdAt: DateFormatManager.shared.chatISOString(from: Date()),
                updatedAt: DateFormatManager.shared.chatISOString(from: Date()),
                sender: ChatSender(userID: "me", nick: "나", profileImage: nil),
                files: []
            ),
            isMine: true,
            status: .sending
        ) {}

        ChatBubbleView(
            message: ChatMessage(
                chatID: "preview-3",
                roomID: "room-preview",
                content: "사진도 같이 보낼게요.",
                createdAt: DateFormatManager.shared.chatISOString(from: Date()),
                updatedAt: DateFormatManager.shared.chatISOString(from: Date()),
                sender: ChatSender(userID: "me", nick: "나", profileImage: nil),
                files: []
            ),
            isMine: true,
            status: .failed
        ) {}
    }
    .padding()
    .background(YPColor.backgroundPrimary)
}
