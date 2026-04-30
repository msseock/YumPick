import SwiftUI

struct HomePickupStoreRow: View {
    var store: StoreSummary
    var isLiked: Bool
    var onLikeTapped: () -> Void

    private let imageHeight: CGFloat = 132
    private let sideImageWidth: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            imageGrid
            storeInfo
            hashtagRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(YPColor.backgroundPrimary)
    }

    private var imageGrid: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                CachedImage(path: store.store_image_urls?.first)
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                YPLikeButton(isLiked: isLiked, action: onLikeTapped)
                    .padding(10)

                if store.is_picchelin ?? false {
                    YPPickchelinTag()
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }

            VStack(spacing: 4) {
                sideImage(at: 1)
                sideImage(at: 2)
            }
            .frame(width: sideImageWidth, height: imageHeight)
        }
        .frame(height: imageHeight)
    }

    private func sideImage(at index: Int) -> some View {
        CachedImage(path: imagePath(at: index))
            .frame(width: sideImageWidth, height: (imageHeight - 4) / 2)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var storeInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(store.name ?? "")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)

                pickupCount
                rating
            }

            HStack(spacing: 16) {
                statItem(icon: "Distance", text: distanceText)
                statItem(icon: "Time", text: store.close ?? "")
                statItem(icon: "Run", text: "\(store.total_order_count ?? 0)회")
            }
        }
    }

    private var pickupCount: some View {
        HStack(spacing: 2) {
            Image("Like_Fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(YPColor.actionAccent)

            Text("\(store.pick_count ?? 0)개")
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textPrimary)
        }
    }

    private var rating: some View {
        HStack(spacing: 2) {
            Image("Star_Fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(YPColor.actionAccent)

            Text(ratingText)
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textPrimary)

            Text("(\(store.total_review_count ?? 0))")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)
        }
    }

    @ViewBuilder
    private var hashtagRow: some View {
        if let hashTags = store.hashTags, !hashTags.isEmpty {
            HStack(spacing: 6) {
                ForEach(hashTags.prefix(3), id: \.self) { tag in
                    Text(tag.hasPrefix("#") ? tag : "#\(tag)")
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.backgroundPrimary)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(YPColor.brandDeepSprout)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func statItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(YPColor.textSecondary)

            Text(text)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
                .lineLimit(1)
        }
    }

    private func imagePath(at index: Int) -> String? {
        guard let urls = store.store_image_urls, urls.indices.contains(index) else {
            return nil
        }
        return urls[index]
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
