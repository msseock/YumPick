import SwiftUI

struct YPBannerCarousel: View {
    let banners: [Banner]
    var onBannerTapped: (Banner) -> Void

    @State private var currentPage = 0
    @State private var aspectRatios: [Int: CGFloat] = [:]

    private let defaultAspectRatio: CGFloat = 390 / 140

    var body: some View {
        if banners.isEmpty {
            YPColor.backgroundSecondary
                .frame(maxWidth: .infinity)
                .aspectRatio(defaultAspectRatio, contentMode: .fit)
        } else {
            TabView(selection: $currentPage) {
                ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                    Button {
                        onBannerTapped(banner)
                    } label: {
                        CachedImage(path: banner.imageUrl) { imageSize in
                            updateAspectRatio(for: index, imageSize: imageSize)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(currentAspectRatio, contentMode: .fit)
            .overlay(alignment: .bottomTrailing) {
                Text(bannerIndexText)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.backgroundPrimary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(YPColor.gray90.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    private var currentAspectRatio: CGFloat {
        aspectRatios[currentPage] ?? defaultAspectRatio
    }

    private var bannerIndexText: String {
        let count = banners.count
        let current = min(currentPage + 1, count)
        return "\(current)/\(count)"
    }

    private func updateAspectRatio(for index: Int, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        aspectRatios[index] = imageSize.width / imageSize.height
    }
}
