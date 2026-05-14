import SwiftUI

/// 얌픽 v2.0 비디오 hero 카드. Pencil h16RGx의 Hero Video 블록.
/// view_count 최대 영상을 큰 이미지 + 중앙 재생 버튼 + 타이틀/메타/CTA로 표시.
struct YP2VideoHeroCard: View {
    let video: Video
    let onTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    CachedImage(path: video.thumbnail_url)
                        .frame(width: width, height: 390)
                        .clipped()

                    Color.black.opacity(0.4)
                        .frame(width: width, height: 390)

                    // 중앙 재생 버튼
                    ZStack {
                        Circle()
                            .fill(YP2Color.order)
                            .frame(width: 62, height: 62)

                        Image(systemName: "play")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(YP2Color.ink)
                            .offset(x: 2)
                    }
                    .frame(width: width, height: 390)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(video.like_count)")
                                    .font(.custom("Pretendard-Bold", size: 12))
                            }
                            .foregroundStyle(YP2Color.order)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(YP2Color.ink.opacity(0.85))
                            .clipShape(Capsule())
                            Spacer(minLength: 0)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(video.title)
                                .font(.custom("Pretendard-Bold", size: 25))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("조회 \(formattedViewCount(video.view_count))")
                                .font(.custom("Pretendard-Bold", size: 13))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(width: width, height: 390)
                }
                .frame(width: width, height: 390)
                .clipped()
            }
            .buttonStyle(.plain)
        }
        .frame(height: 390)
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
