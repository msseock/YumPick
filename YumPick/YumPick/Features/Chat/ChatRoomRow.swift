import SwiftUI

struct ChatRoomRow: View {
    let room: ChatRoom
    let opponent: ChatSender?
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(path: opponent?.profileImage)
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(opponent?.nick ?? "알 수 없음")
                    .ypFont(YPFont.body2Bold)
                    .foregroundStyle(YPColor.textPrimary)
                if let last = room.lastChat {
                    Text(last.content.isEmpty ? "이미지" : last.content)
                        .ypFont(YPFont.caption1)
                        .foregroundStyle(YPColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(DateFormatManager.shared.relativeDate(from: room.updatedAt))
                    .ypFont(YPFont.caption2)
                    .foregroundStyle(YPColor.textTertiary)
                if unreadCount > 0 {
                    Text("\(min(unreadCount, 99))")
                        .ypFont(YPFont.caption2)
                        .foregroundStyle(YPColor.gray0)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(YPColor.actionPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
