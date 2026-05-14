import SwiftUI

/// 얌픽 v2.0 비디오 숏 카드. Pencil h16RGx의 "인기 숏폼" 그리드용.
/// 이미지 + 하단 그라디언트 + 타이틀/조회수 오버레이.
struct YP2VideoShortCard: View {
    let video: Video
    var onTap: (() -> Void)? = nil

    private let cardHeight: CGFloat = 170

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            Group {
                if let onTap {
                    Button(action: onTap) {
                        cardBody(width: width)
                    }
                    .buttonStyle(.plain)
                } else {
                    cardBody(width: width)
                }
            }
            .frame(width: width, height: cardHeight)
        }
        .frame(height: cardHeight)
    }

    private func cardBody(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(path: video.thumbnail_url)
                .frame(width: width, height: cardHeight)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: width, height: cardHeight)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.custom("Pretendard-Bold", size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.15)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(formattedViewCount(video.view_count)) 조회")
                    .font(.custom("Pretendard-Medium", size: 11))
                    .foregroundStyle(YP2Color.order)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width, height: cardHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formattedViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
