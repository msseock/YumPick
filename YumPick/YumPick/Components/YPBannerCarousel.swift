import SwiftUI

struct YPBannerCarousel: View {
    let banners: [Banner]
    var onBannerTapped: (Banner) -> Void

    @State private var currentPage = 0
    @State private var aspectRatios: [Int: CGFloat] = [:]

    private let defaultAspectRatio: CGFloat = 390 / 140

    /// 배너 높이 상한. 이미지 종횡비에 따라 계산하되 hero 섹션과 겹치지 않도록 상한선을 둔다.
    private let maxBannerHeight: CGFloat = 200

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if banners.isEmpty {
                    YPColor.backgroundSecondary
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                            Button {
                                onBannerTapped(banner)
                            } label: {
                                CachedImage(path: banner.imageUrl) { imageSize in
                                    updateAspectRatio(for: index, imageSize: imageSize)
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .buttonStyle(.plain)
                            .tag(index)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if !banners.isEmpty {
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
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .clipped()
        .mask(Rectangle())
    }

    /// 화면 폭을 기준으로 현재 배너의 종횡비에 맞춰 명시적 높이를 계산하되,
    /// 비정상적으로 길쭉한 이미지가 와도 hero 섹션과 겹치지 않도록 상한을 둔다.
    private var bannerHeight: CGFloat {
        let width = UIScreen.main.bounds.width
        let computed = width / currentAspectRatio
        return min(max(computed, 80), maxBannerHeight)
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
