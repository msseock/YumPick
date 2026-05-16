import SwiftUI

struct ChatRoomRow: View {
    let room: ChatRoom
    let opponent: ChatSender?
    let unreadCount: Int
    let lastChat: ChatMessage?

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(displayOpponent?.nick ?? "알 수 없음")
                        .font(.custom("Pretendard-Bold", size: 15))
                        .foregroundStyle(YP2Color.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 12)

                    Text(DateFormatManager.shared.relativeDate(from: room.updatedAt))
                        .font(.custom("Pretendard-Bold", size: 12))
                        .foregroundStyle(YP2Color.textTertiary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(lastMessageText)
                        .font(.custom("Pretendard-Bold", size: 13))
                        .foregroundStyle(YP2Color.textTertiary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if unreadCount > 0 {
                        Text("\(min(unreadCount, 99))")
                            .ypFont(YPFont.caption2)
                            .foregroundStyle(YP2Color.paper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(YP2Color.actionInk)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .frame(maxWidth: .infinity)
        .background(YP2Color.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatar: some View {
        if displayOpponent?.profileImage?.isEmpty == false {
            CachedImage(path: displayOpponent?.profileImage)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(YP2Color.borderSubtle)
                .frame(width: 50, height: 50)
        }
    }

    private var lastMessageText: String {
        guard let lastChat else { return "" }
        if !lastChat.content.isEmpty { return lastChat.content }
        return lastChat.files.isEmpty ? "" : "사진을 보냈습니다"
    }

    private var displayOpponent: ChatSender? {
        guard let opponent else { return nil }
        return ChatUserDirectory.shared.profile(for: opponent.userID) ?? opponent
    }
}
