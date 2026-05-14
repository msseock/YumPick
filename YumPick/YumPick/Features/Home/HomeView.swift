import SwiftUI

private enum HomeScrollTarget {
    static let pickupStoresTop = "pickupStoresTop"
}

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var bannerWebViewRoute: HomeBannerWebViewRoute?
    @State private var isNearbyPaginationArmed = false
    @State private var isNearbyPaginationTriggerVisible = false
    @State private var nearbyPaginationTask: Task<Void, Never>?

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
                            categoryTabsSection
                            bannerSection
                            heroSection
                            popularStoresSection
                            pickupStoresSection(scrollProxy: scrollProxy)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in armNearbyPagination() }
                    )
                    .background(YP2Color.paper)
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YUMPICK")
                    .font(.custom("Pretendard-Bold", size: 34))
                    .foregroundStyle(YP2Color.ink)

                Text(viewModel.currentLocationTitle)
                    .font(YPFont.caption1)
                    .foregroundStyle(YP2Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(YP2Color.ink)

                Image(systemName: "bag")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(YP2Color.ink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(YP2Color.paper)
    }

    // MARK: - Category Tabs

    private var categoryTabsSection: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    categoryTab(
                        title: "NOW",
                        isSelected: viewModel.selectedPopularCategory == nil
                    ) {
                        Task { await viewModel.selectPopularCategory(.more) }
                    }
                    ForEach(HomePopularCategory.allCases.filter { $0 != .more }) { category in
                        categoryTab(
                            title: category.title,
                            isSelected: viewModel.selectedPopularCategory == category
                        ) {
                            Task { await viewModel.selectPopularCategory(category) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)
        }
        .background(YP2Color.paper)
    }

    private func categoryTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.custom("Pretendard-Bold", size: 16))
                    .foregroundStyle(isSelected ? YP2Color.ink : YP2Color.textTertiary)

                Rectangle()
                    .fill(isSelected ? YP2Color.ink : Color.clear)
                    .frame(width: 44, height: 3)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Banner

    private var bannerSection: some View {
        VStack(spacing: 0) {
            YPBannerCarousel(banners: viewModel.banners) { banner in
                bannerWebViewRoute = viewModel.webViewRoute(for: banner)
            }

            Rectangle()
                .fill(YP2Color.paper)
                .frame(height: 12)
        }
        .background(YP2Color.paper)
        .zIndex(0)
    }

    // MARK: - Hero (오늘의 픽업)

    @ViewBuilder
    private var heroSection: some View {
        if let store = viewModel.nearbyStores.first {
            NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                GeometryReader { proxy in
                    ZStack {
                        CachedImage(path: store.store_image_urls?.first)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        LinearGradient(
                            colors: [
                                .black.opacity(0.45),
                                .clear,
                                .black.opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("오늘의 픽업")
                                    .font(.custom("Pretendard-Bold", size: 14))
                                    .foregroundStyle(YP2Color.paper)
                                Spacer()
                            }

                            Spacer()

                            HStack(alignment: .bottom, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.name ?? "")
                                        .font(.custom("Pretendard-Bold", size: 26))
                                        .foregroundStyle(YP2Color.paper)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    if let closeTime = store.close, !closeTime.isEmpty {
                                        Text(closeTime + " 마감")
                                            .font(.custom("Pretendard-Bold", size: 13))
                                            .foregroundStyle(YP2Color.paper.opacity(0.95))
                                    }
                                }

                                Spacer()

                                Text("바로보기")
                                    .font(.custom("Pretendard-Bold", size: 13))
                                    .foregroundStyle(YP2Color.ink)
                                    .frame(width: 108, height: 40)
                                    .background(YP2Color.order)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                .frame(height: 238)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zIndex(1)
        }
    }

    // MARK: - Popular Stores (실시간 인기 맛집)

    private var popularStoresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("실시간 인기 맛집")
                    .font(.custom("Pretendard-Bold", size: 22))
                    .foregroundStyle(YP2Color.ink)

                Spacer()

                Text("전체")
                    .font(YPFont.caption1)
                    .foregroundStyle(YP2Color.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            let stores = viewModel.popularStores
            VStack(spacing: 10) {
                ForEach(Array(stride(from: 0, to: stores.count, by: 2)), id: \.self) { index in
                    HStack(spacing: 10) {
                        popularStoreCard(stores[index])
                        if index + 1 < stores.count {
                            popularStoreCard(stores[index + 1])
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 140)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(YP2Color.paper)
    }

    private func popularStoreCard(_ store: StoreSummary) -> some View {
        NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
            ZStack(alignment: .bottomLeading) {
                CachedImage(path: store.store_image_urls?.first)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity)
                .frame(height: 140)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name ?? "")
                        .font(.custom("Pretendard-Bold", size: 14))
                        .foregroundStyle(YP2Color.paper)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text("\(store.pick_count ?? 0) 픽업")
                        .font(.custom("Pretendard-Bold", size: 12))
                        .foregroundStyle(YP2Color.order)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)

                if store.is_picchelin ?? false {
                    VStack {
                        HStack {
                            YP2PickchelinBadge()
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pickup Stores (내 픽업 가게)

    private func pickupStoresSection(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id(HomeScrollTarget.pickupStoresTop)

            HStack {
                Text("내가 픽업 가게")
                    .font(.custom("Pretendard-Bold", size: 22))
                    .foregroundStyle(YP2Color.ink)

                Spacer()

                sortButton(scrollProxy: scrollProxy)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

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
            .padding(.bottom, 8)
            .background(YP2Color.paper)
            .zIndex(1)

            pickupStoreList
        }
        .background(YP2Color.paper)
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
                    .font(.custom("Pretendard-Bold", size: 13))
                    .foregroundStyle(YP2Color.ink)

                Image("List")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(YP2Color.ink)
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
                    .font(.custom("Pretendard-Bold", size: 13))
                    .foregroundStyle(isSelected ? YP2Color.ink : YP2Color.textTertiary)
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
                    .font(.custom("Pretendard-Medium", size: 13))
                    .foregroundStyle(YP2Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }

            ForEach(viewModel.filteredNearbyStores) { store in
                NavigationLink(value: HomePath.storeDetail(storeId: store.store_id)) {
                    YP2PickupStoreCard(
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

                Rectangle()
                    .fill(YP2Color.borderDefault)
                    .frame(height: 1)
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

            Color.clear.frame(height: 100)
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
}
