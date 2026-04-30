import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var bannerPage = 0
    @State private var bannerAspectRatios: [Int: CGFloat] = [:]
    @State private var bannerWebViewRoute: HomeBannerWebViewRoute?

    private let defaultBannerAspectRatio: CGFloat = 390 / 140

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.banners.isEmpty
                && viewModel.popularStores.isEmpty
            {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        searchBarSection
                        popularSearchesSection
                        bannerSection
                        popularStoresSection
                        nearbyStoresSection
                    }
                }
            }
        }
        .task {
            await viewModel.fetchContent()
        }
        .sheet(item: $bannerWebViewRoute) { route in
            HomeBannerWebViewScreen(url: route.url)
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var bannerSection: some View {
        if viewModel.banners.isEmpty {
            Color(YPColor.backgroundSecondary)
                .frame(maxWidth: .infinity)
                .aspectRatio(defaultBannerAspectRatio, contentMode: .fit)
        } else {
            TabView(selection: $bannerPage) {
                ForEach(Array(viewModel.banners.enumerated()), id: \.offset) {
                    index,
                    banner in
                    Button {
                        bannerWebViewRoute = viewModel.webViewRoute(for: banner)
                    } label: {
                        CachedImage(path: banner.imageUrl) { imageSize in
                            updateBannerAspectRatio(
                                for: index,
                                imageSize: imageSize
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .aspectRatio(currentBannerAspectRatio, contentMode: .fit)
        }
    }

    private var currentBannerAspectRatio: CGFloat {
        bannerAspectRatios[bannerPage] ?? defaultBannerAspectRatio
    }

    private func updateBannerAspectRatio(for index: Int, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        bannerAspectRatios[index] = imageSize.width / imageSize.height
    }

    // MARK: - Search Bar

    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(YPColor.textTertiary)
            Text("가게 또는 메뉴를 검색해보세요")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Popular Searches

    private var popularSearchesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.popularSearches, id: \.self) { keyword in
                    Text(keyword)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Nearby Stores

    private var nearbyStoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("내 주변")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.nearbyStores) { store in
                        NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                            YPPopularShopCard(
                                imagePath: store.store_image_urls?.first,
                                shopName: store.name ?? "",
                                pickupCount: store.pick_count ?? 0,
                                distance: store.distance.map { String(format: "%.0fm", $0) } ?? "",
                                closeTime: store.close ?? "",
                                visitCount: store.total_order_count ?? 0,
                                isLiked: store.is_pick ?? false,
                                isPickchelin: store.is_picchelin ?? false,
                                onLikeTapped: {
                                    Task { await viewModel.toggleLike(storeId: store.store_id) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Popular Stores

    private var popularStoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("실시간 인기")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.popularStores) { store in
                        NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                            YPPopularShopCard(
                                imagePath: store.store_image_urls?.first,
                                shopName: store.name ?? "",
                                pickupCount: store.pick_count ?? 0,
                                distance: "",
                                closeTime: store.close ?? "",
                                visitCount: store.total_order_count ?? 0,
                                isLiked: store.is_pick ?? false,
                                isPickchelin: store.is_picchelin ?? false,
                                onLikeTapped: {
                                    Task { await viewModel.toggleLike(storeId: store.store_id) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
    }
}
