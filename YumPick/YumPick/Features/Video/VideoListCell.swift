import SwiftUI

struct VideoListCell: View {
    let video: Video

    private var likeState: VideoLikeStateStore.State {
        VideoLikeStateStore.shared.state(
            for: video.video_id,
            fallback: .init(isLiked: video.is_liked, likeCount: video.like_count)
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(path: video.thumbnail_url)
                .frame(width: 140, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text(formattedDuration(video.duration))
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.gray0)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(YPColor.gray100.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(YPFont.body2Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(video.view_count)", systemImage: "eye")
                    let state = likeState
                    Label("\(state.likeCount)", systemImage: state.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(state.isLiked ? YPColor.actionAccent : YPColor.textSecondary)
                }
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
