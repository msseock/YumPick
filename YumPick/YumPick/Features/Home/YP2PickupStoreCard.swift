import SwiftUI

/// 얌픽 v2.0 픽업 가게 카드.
/// 이미지 개수에 따라 레이아웃이 달라진다:
/// - 0~1장: 단일 대형 이미지
/// - 2장: 좌우 1:1
/// - 3장 이상: 좌측 메인 + 우측 세로 2장
struct YP2PickupStoreCard: View {
    var store: StoreSummary
    var isLiked: Bool
    var onLikeTapped: () -> Void

    private let totalImageHeight: CGFloat = 200
    private let imageSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            imageSection
            infoSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(YP2Color.paper)
    }

    // MARK: - Image Layouts

    private var imagePaths: [String] {
        store.store_image_urls ?? []
    }

    @ViewBuilder
    private var imageSection: some View {
        GeometryReader { proxy in
            imageGrid(size: proxy.size)
                .overlay(alignment: .topTrailing) {
                    likeButton
                        .padding(10)
                }
        }
        .frame(height: totalImageHeight)
        .clipped()
    }

    @ViewBuilder
    private func imageGrid(size: CGSize) -> some View {
        let width = max(size.width, 0)
        let height = totalImageHeight

        switch imagePaths.count {
        case 0:
            mainImageBlock(path: nil, width: width, height: height)
        case 1:
            mainImageBlock(path: imagePaths[0], width: width, height: height)
        case 2:
            let itemWidth = max((width - imageSpacing) / 2, 0)
            HStack(spacing: imageSpacing) {
                mainImageBlock(path: imagePaths[0], width: itemWidth, height: height)
                sideImage(path: imagePaths[1], width: itemWidth, height: height)
            }
            .frame(width: width, height: height)
        default:
            let sideWidth = min(100, max((width - imageSpacing) * 0.32, 0))
            let mainWidth = max(width - sideWidth - imageSpacing, 0)
            let sideHeight = max((height - imageSpacing) / 2, 0)
            HStack(spacing: imageSpacing) {
                mainImageBlock(path: imagePaths[0], width: mainWidth, height: height)

                VStack(spacing: imageSpacing) {
                    sideImage(path: imagePaths[1], width: sideWidth, height: sideHeight)
                    sideImage(path: imagePaths[2], width: sideWidth, height: sideHeight)
                }
                .frame(width: sideWidth, height: height)
                .clipped()
            }
            .frame(width: width, height: height)
        }
    }

    private func mainImageBlock(path: String?, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            CachedImage(path: path)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if store.is_picchelin ?? false {
                YP2PickchelinBadge()
                    .padding(10)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var likeButton: some View {
        Button(action: onLikeTapped) {
            Image(isLiked ? "Like_Fill" : "Like_Empty")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(isLiked ? YP2Color.order : YP2Color.paper)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func sideImage(path: String?, width: CGFloat, height: CGFloat) -> some View {
        CachedImage(path: path)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipped()
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.name ?? "")
                .font(.custom("Pretendard-Bold", size: 18))
                .foregroundStyle(YP2Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: 12) {
                stat(icon: "Like_Fill", text: "\(store.pick_count ?? 0)", tint: YP2Color.order)
                stat(icon: "Star_Fill", text: ratingText, tint: YP2Color.order)
                stat(icon: "Distance", text: distanceText, tint: YP2Color.textSecondary)
                stat(icon: "Time", text: store.close ?? "", tint: YP2Color.textSecondary)
            }

            hashtagRow
        }
    }

    private func stat(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(tint)

            Text(text)
                .font(.custom("Pretendard-Bold", size: 13))
                .foregroundStyle(YP2Color.textPrimary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var hashtagRow: some View {
        if let hashTags = store.hashTags, !hashTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(hashTags.prefix(4), id: \.self) { tag in
                        Text(tag.hasPrefix("#") ? tag : "#\(tag)")
                            .font(.custom("Pretendard-Medium", size: 12))
                            .foregroundStyle(YP2Color.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(YP2Color.fog)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
    }

    private var ratingText: String {
        String(format: "%.1f", store.total_rating ?? 0)
    }

    private var distanceText: String {
        guard let distance = store.distance else { return "" }
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        }
        return String(format: "%.0fm", distance)
    }
}
