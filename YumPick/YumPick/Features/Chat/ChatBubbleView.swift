import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isMine: Bool
    let status: ChatMessageStatus
    var namespace: Namespace.ID
    let onRetry: () -> Void
    var onImageTapped: (Int) -> Void = { _ in }
    var onPDFTapped: (String) -> Void = { _ in }

    private let gridWidth: CGFloat = 224
    private let gap: CGFloat = 4

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
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

                if !message.files.isEmpty {
                    let split = message.files.splitMediaAndPDF()
                    if !split.pdfs.isEmpty {
                        ForEach(split.pdfs, id: \.self) { path in
                            ChatPDFCard(path: path) { onPDFTapped(path) }
                                .opacity(status == .sending ? 0.6 : 1.0)
                        }
                    }
                    if !split.media.isEmpty {
                        imageGrid(files: split.media)
                            .overlay(alignment: .topTrailing) {
                                if split.media.count > 1 {
                                    countBadge(split.media.count)
                                }
                            }
                            .opacity(status == .sending ? 0.6 : 1.0)
                    }
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

    // MARK: - Image Grid

    @ViewBuilder
    private func imageGrid(files: [String]) -> some View {
        let half = (gridWidth - gap) / 2
        let third = (gridWidth - gap * 2) / 3

        switch files.count {
        case 1:
            cell(files[0], idx: 0, w: gridWidth, h: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))

        case 2:
            HStack(spacing: gap) {
                cell(files[0], idx: 0, w: half, h: 160)
                cell(files[1], idx: 1, w: half, h: 160)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case 3:
            HStack(alignment: .top, spacing: gap) {
                cell(files[0], idx: 0, w: half + 36, h: 200)
                VStack(spacing: gap) {
                    cell(files[1], idx: 1, w: half - 36, h: 98)
                    cell(files[2], idx: 2, w: half - 36, h: 98)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case 4:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    cell(files[0], idx: 0, w: half, h: half)
                    cell(files[1], idx: 1, w: half, h: half)
                }
                HStack(spacing: gap) {
                    cell(files[2], idx: 2, w: half, h: half)
                    cell(files[3], idx: 3, w: half, h: half)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case 5:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    cell(files[0], idx: 0, w: half, h: half)
                    cell(files[1], idx: 1, w: half, h: half)
                }
                HStack(spacing: gap) {
                    cell(files[2], idx: 2, w: third, h: third)
                    cell(files[3], idx: 3, w: third, h: third)
                    cell(files[4], idx: 4, w: third, h: third)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

        default:
            EmptyView()
        }
    }

    private func cell(_ path: String, idx: Int, w: CGFloat, h: CGFloat) -> some View {
        CachedImage(path: path)
            .scaledToFill()
            .frame(width: w, height: h)
            .clipped()
            .matchedGeometryEffect(id: path, in: namespace)
            .contentShape(Rectangle())
            .onTapGesture { onImageTapped(idx) }
    }

    private func countBadge(_ count: Int) -> some View {
        Label("\(count)", systemImage: "photo.on.rectangle")
            .ypFont(YPFont.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5))
            .clipShape(Capsule())
            .padding(6)
    }

    // MARK: - Helpers

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
            status: .sent,
            namespace: Namespace().wrappedValue
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
            status: .sending,
            namespace: Namespace().wrappedValue
        ) {}
    }
    .padding()
    .background(YPColor.backgroundPrimary)
}
