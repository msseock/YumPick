import SwiftUI

private enum HomeScrollTarget {
    static let pickupStoresTop = "pickupStoresTop"
}

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var bannerPage = 0
    @State private var bannerAspectRatios: [Int: CGFloat] = [:]
    @State private var bannerWebViewRoute: HomeBannerWebViewRoute?
    @State private var isNearbyPaginationArmed = false
    @State private var isNearbyPaginationTriggerVisible = false
    @State private var nearbyPaginationTask: Task<Void, Never>?

    private let defaultBannerAspectRatio: CGFloat = 390 / 140

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.banners.isEmpty
                && viewModel.popularStores.isEmpty
                && viewModel.nearbyStores.isEmpty
            {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            headerSection
                            categoryFilterSection
                            popularStoresSection
                            bannerSection
                                .padding(.top, 24)
                            pickupStoresSection(scrollProxy: scrollProxy)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in
                                armNearbyPagination()
                            }
                    )
                    .background(YPColor.backgroundPrimary)
                }
            }
        }
        .task {
            await viewModel.fetchContent()
        }
        .onDisappear {
            nearbyPaginationTask?.cancel()
            nearbyPaginationTask = nil
        }
        .sheet(item: $bannerWebViewRoute) { route in
            HomeBannerWebViewScreen(url: route.url)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            currentLocationRow
            searchBarSection
            popularSearchesSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YPColor.backgroundBrandSubtle)
    }

    private var currentLocationRow: some View {
        HStack(spacing: 8) {
            Image("Location")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(YPColor.textPrimary)

            Text(viewModel.currentLocationTitle)
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(YPColor.textPrimary)

            Spacer()
        }
        .frame(height: 28)
    }

    private var searchBarSection: some View {
        HStack(spacing: 8) {
            Image("Search")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(YPColor.textTertiary)

            Text("검색어를 입력해주세요.")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(YPColor.backgroundPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(YPColor.brandDeepSprout, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var popularSearchesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("✦ 인기검색어")
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.brandDeepSprout)

                ForEach(Array(viewModel.popularSearches.prefix(5)), id: \.self) { keyword in
                    Text(keyword)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.brandBlackSprout)
                }
            }
        }
        .frame(height: 16)
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(HomePopularCategory.allCases) { category in
                popularCategoryButton(category)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YPColor.backgroundPrimary)
    }

    private func popularCategoryButton(_ category: HomePopularCategory) -> some View {
        let isSelected = viewModel.selectedPopularCategory == category

        return Button {
            Task {
                await viewModel.selectPopularCategory(category)
            }
        } label: {
            VStack(spacing: 8) {
                Image(category.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(width: 56, height: 56)
                    .background(YPColor.gray0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? YPColor.brandBlackSprout : YPColor.gray30,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(category.title)
                    .font(YPFont.body3)
                    .foregroundStyle(isSelected ? YPColor.brandBlackSprout : YPColor.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 64)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Popular Stores

    private var popularStoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("실시간 인기 맛집")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.popularStores) { store in
                        NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                            YPPopularShopCard(
                                imagePath: store.store_image_urls?.first,
                                shopName: store.name ?? "",
                                pickupCount: store.pick_count ?? 0,
                                distance: store.distance.map { formattedDistance($0) } ?? "",
                                closeTime: store.close ?? "",
                                visitCount: store.total_order_count ?? 0,
                                isLiked: LikeStateStore.shared.isLiked(
                                    for: store.store_id,
                                    fallback: store.is_pick ?? false
                                ),
                                isPickchelin: store.is_picchelin ?? false,
                                onLikeTapped: {
                                    Task { await viewModel.toggleLike(storeId: store.store_id) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 2)
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
                ForEach(Array(viewModel.banners.enumerated()), id: \.offset) { index, banner in
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
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(currentBannerAspectRatio, contentMode: .fit)
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

    private var currentBannerAspectRatio: CGFloat {
        bannerAspectRatios[bannerPage] ?? defaultBannerAspectRatio
    }

    private var bannerIndexText: String {
        let count = viewModel.banners.count
        let current = min(bannerPage + 1, count)
        return "\(current)/\(count)"
    }

    private func updateBannerAspectRatio(for index: Int, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        bannerAspectRatios[index] = imageSize.width / imageSize.height
    }

    // MARK: - Pickup Stores

    private func pickupStoresSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(HomeScrollTarget.pickupStoresTop)

            HStack {
                Text("내가 픽업 가게")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)

                Spacer()

                sortButton(scrollProxy: scrollProxy)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack(spacing: 12) {
                pickupFilterButton(
                    title: "픽슐랭",
                    isSelected: viewModel.isPickchelinFilterOn,
                    action: viewModel.togglePickchelinFilter
                )

                pickupFilterButton(
                    title: "My Pick",
                    isSelected: viewModel.isMyPickFilterOn,
                    action: viewModel.toggleMyPickFilter
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(YPColor.backgroundPrimary)
            .zIndex(1)

            pickupStoreList
        }
    }

    private func sortButton(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(HomeScrollTarget.pickupStoresTop, anchor: .top)
            }
            Task {
                await viewModel.advanceNearbySort()
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.nearbySort.title)
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.brandBlackSprout)

                Image("List")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(YPColor.brandBlackSprout)
            }
        }
        .buttonStyle(.plain)
    }

    private func pickupFilterButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                YPCheckBox(isChecked: isSelected)

                Text(title)
                    .font(YPFont.body3)
                    .foregroundStyle(isSelected ? YPColor.brandBlackSprout : YPColor.textTertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var pickupStoreList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isNearbyPageLoading && viewModel.nearbyStores.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if viewModel.filteredNearbyStores.isEmpty {
                Text("조건에 맞는 가게가 없어요.")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }

            ForEach(viewModel.filteredNearbyStores) { store in
                NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                    HomePickupStoreRow(
                        store: store,
                        isLiked: LikeStateStore.shared.isLiked(
                            for: store.store_id,
                            fallback: store.is_pick ?? false
                        ),
                        onLikeTapped: {
                            Task { await viewModel.toggleLike(storeId: store.store_id) }
                        }
                    )
                }
                .buttonStyle(.plain)

                YPDivider()
                    .padding(.horizontal, 20)
            }

            if viewModel.canLoadMoreNearbyStores {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
                    .onAppear {
                        isNearbyPaginationTriggerVisible = true
                        triggerNearbyPaginationIfNeeded()
                    }
                    .onDisappear {
                        isNearbyPaginationTriggerVisible = false
                    }
            }

            if viewModel.isNearbyPageLoading && !viewModel.nearbyStores.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        }
    }

    private func armNearbyPagination() {
        isNearbyPaginationArmed = true
        triggerNearbyPaginationIfNeeded()
    }

    private func triggerNearbyPaginationIfNeeded() {
        guard isNearbyPaginationArmed else { return }
        guard isNearbyPaginationTriggerVisible else { return }
        guard viewModel.canLoadMoreNearbyStores else { return }
        guard nearbyPaginationTask == nil else { return }

        isNearbyPaginationArmed = false
        nearbyPaginationTask = Task {
            await viewModel.loadMoreNearbyStores()
            await MainActor.run {
                nearbyPaginationTask = nil
            }
        }
    }

    private func formattedDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        }
        return String(format: "%.0fm", distance)
    }
}
