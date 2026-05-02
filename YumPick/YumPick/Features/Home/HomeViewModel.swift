import Foundation

private let seoulCityHall = Geolocation(longitude: 126.9780, latitude: 37.5665)

enum HomePopularCategory: String, CaseIterable, Identifiable {
    case coffee = "커피"
    case fastFood = "패스트푸드"
    case dessert = "디저트"
    case bakery = "베이커리"
    case more = "more"

    var id: String { rawValue }
    var title: String { rawValue }

    var imageName: String {
        switch self {
        case .coffee: return "Coffee"
        case .fastFood: return "FastFood"
        case .dessert: return "Dessert"
        case .bakery: return "Bakery"
        case .more: return "More"
        }
    }
}

enum HomeNearbySort: String {
    case distance
    case orders
    case reviews

    var title: String {
        switch self {
        case .distance: return "거리순"
        case .orders: return "주문순"
        case .reviews: return "리뷰순"
        }
    }

    var next: HomeNearbySort {
        switch self {
        case .distance: return .orders
        case .orders: return .reviews
        case .reviews: return .distance
        }
    }
}

struct HomeBannerWebViewRoute: Identifiable, Equatable {
    let url: URL

    var id: String { url.absoluteString }
}

@MainActor
@Observable
final class HomeViewModel {
    var banners: [Banner] = []
    var popularStores: [StoreSummary] = []
    var popularSearches: [String] = []
    var nearbyStores: [StoreSummary] = []
    var selectedPopularCategory: HomePopularCategory? = nil
    var nearbySort: HomeNearbySort = .distance
    var isPickchelinFilterOn = false
    var isMyPickFilterOn = false
    var isNearbyPageLoading = false
    var currentLocationTitle = "현재 위치"
    var isLoading = false
    var errorMessage: String? = nil

    private var hasLoaded = false
    private var currentGeolocation: Geolocation?
    private var nearbyNextCursor: String?
    private var hasMoreNearbyStores = false
    private var loadedNearbyCursors = Set<String>()
    private let client: HomeClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: HomeClientProtocol = HomeClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    var filteredNearbyStores: [StoreSummary] {
        guard isPickchelinFilterOn || isMyPickFilterOn else {
            return nearbyStores
        }

        return nearbyStores.filter { store in
            let matchesPickchelin = isPickchelinFilterOn && (store.is_picchelin ?? false)
            let matchesMyPick = isMyPickFilterOn && LikeStateStore.shared.isLiked(
                for: store.store_id,
                fallback: store.is_pick ?? false
            )
            return matchesPickchelin || matchesMyPick
        }
    }

    var canLoadMoreNearbyStores: Bool {
        hasMoreNearbyStores && !isNearbyPageLoading
    }

    func fetchContent() async {
        guard !hasLoaded && !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let banners = client.fetchBanners()
            async let popularStores = client.fetchPopularStores(category: nil)
            async let popularSearches = client.fetchPopularSearches()
            self.banners = try await banners
            self.popularStores = try await popularStores
            self.popularSearches = try await popularSearches
            HomeStoreCache.popularStores = self.popularStores
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshNearbyStores()
    }

    func selectPopularCategory(_ category: HomePopularCategory) async {
        let shouldDeselect = selectedPopularCategory == category || category == .more

        if shouldDeselect {
            guard selectedPopularCategory != nil else { return }
            selectedPopularCategory = nil
            await restoreOriginalContent()
        } else {
            selectedPopularCategory = category
            await applyCategory(category)
        }
    }

    private func applyCategory(_ category: HomePopularCategory) async {
        do {
            popularStores = try await client.fetchPopularStores(category: category.title)
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshNearbyStores()
    }

    private func restoreOriginalContent() async {
        if let cached = HomeStoreCache.popularStores {
            popularStores = cached
        } else {
            do {
                popularStores = try await client.fetchPopularStores(category: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        if let cachedPage = HomeStoreCache.nearbyFirstPage,
           let cachedSort = HomeNearbySort(rawValue: cachedPage.sort),
           cachedSort == nearbySort
        {
            nearbyStores = cachedPage.stores
            nearbyNextCursor = cachedPage.nextCursor
            hasMoreNearbyStores = cachedPage.nextCursor != nil
            loadedNearbyCursors.removeAll()
        } else {
            await refreshNearbyStores()
        }
    }

    func advanceNearbySort() async {
        nearbySort = nearbySort.next
        await refreshNearbyStores()
    }

    func togglePickchelinFilter() {
        isPickchelinFilterOn.toggle()
    }

    func toggleMyPickFilter() {
        isMyPickFilterOn.toggle()
    }

    func loadMoreNearbyStores() async {
        await fetchNearbyStores(reset: false)
    }

    func toggleLike(storeId: String) async {
        let popularIdx = popularStores.firstIndex(where: { $0.store_id == storeId })
        let nearbyIdx = nearbyStores.firstIndex(where: { $0.store_id == storeId })
        guard popularIdx != nil || nearbyIdx != nil else { return }

        func toggled(_ store: StoreSummary) -> StoreSummary {
            let currentLiked = LikeStateStore.shared.isLiked(for: store.store_id, fallback: store.is_pick ?? false)
            let newPick = !currentLiked
            return StoreSummary(
                store_id: store.store_id, category: store.category, name: store.name,
                close: store.close, store_image_urls: store.store_image_urls,
                is_picchelin: store.is_picchelin, is_pick: newPick,
                pick_count: (store.pick_count ?? 0) + (newPick ? 1 : -1),
                hashTags: store.hashTags, total_rating: store.total_rating,
                total_order_count: store.total_order_count,
                total_review_count: store.total_review_count,
                geolocation: store.geolocation, distance: store.distance,
                createdAt: store.createdAt, updatedAt: store.updatedAt
            )
        }

        let originalPopular = popularIdx.map { popularStores[$0] }
        let originalNearby = nearbyIdx.map { nearbyStores[$0] }

        if let i = popularIdx { popularStores[i] = toggled(popularStores[i]) }
        if let i = nearbyIdx { nearbyStores[i] = toggled(nearbyStores[i]) }

        let newLikeStatus = popularIdx.map { popularStores[$0].is_pick ?? false }
            ?? nearbyIdx.map { nearbyStores[$0].is_pick ?? false }
            ?? false

        do {
            _ = try await client.toggleLike(storeId: storeId, likeStatus: newLikeStatus)
            LikeStateStore.shared.update(storeId: storeId, isLiked: newLikeStatus)
        } catch {
            if let i = popularIdx, let original = originalPopular { popularStores[i] = original }
            if let i = nearbyIdx, let original = originalNearby { nearbyStores[i] = original }
        }
    }

    func webViewRoute(for banner: Banner) -> HomeBannerWebViewRoute? {
        guard banner.payload.type == "WEBVIEW" else { return nil }
        guard let url = Self.resolveWebViewURL(from: banner.payload.value) else { return nil }
        return HomeBannerWebViewRoute(url: url)
    }

    private static func resolveWebViewURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        let base = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        return URL(string: base + path)
    }

    private func refreshNearbyStores() async {
        await fetchNearbyStores(reset: true)
    }

    private func fetchNearbyStores(reset: Bool) async {
        guard reset || hasMoreNearbyStores else { return }
        guard !isNearbyPageLoading else { return }

        let requestedCursor = reset ? nil : nearbyNextCursor
        if !reset {
            guard let requestedCursor else {
                hasMoreNearbyStores = false
                return
            }
            guard !loadedNearbyCursors.contains(requestedCursor) else {
                hasMoreNearbyStores = false
                nearbyNextCursor = nil
                return
            }
        }

        if reset {
            nearbyStores = []
            nearbyNextCursor = nil
            hasMoreNearbyStores = true
            loadedNearbyCursors.removeAll()
        }

        isNearbyPageLoading = true
        defer { isNearbyPageLoading = false }

        let geo = await resolvedCurrentGeolocation()
        do {
            let page = try await client.fetchNearbyStores(
                longitude: geo.longitude,
                latitude: geo.latitude,
                orderBy: nearbySort.rawValue,
                category: selectedPopularCategory?.title,
                next: requestedCursor
            )

            if let requestedCursor {
                loadedNearbyCursors.insert(requestedCursor)
            }

            if reset {
                nearbyStores = page.stores
            } else {
                nearbyStores.append(contentsOf: page.stores)
            }

            let hasNewStores = !page.stores.isEmpty

            if hasNewStores,
               let nextCursor = page.stores.last?.store_id,
               nextCursor != requestedCursor,
               !loadedNearbyCursors.contains(nextCursor)
            {
                nearbyNextCursor = nextCursor
                hasMoreNearbyStores = true
            } else {
                nearbyNextCursor = nil
                hasMoreNearbyStores = false
            }

            if reset && selectedPopularCategory == nil {
                HomeStoreCache.nearbyFirstPage = HomeNearbyFirstPageCache(
                    stores: nearbyStores,
                    nextCursor: nearbyNextCursor,
                    sort: nearbySort.rawValue
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            hasMoreNearbyStores = false
        }
    }

    private func resolvedCurrentGeolocation() async -> Geolocation {
        if let currentGeolocation {
            return currentGeolocation
        }
        let geo = await locationManager.currentLocation() ?? seoulCityHall
        currentGeolocation = geo
        return geo
    }
}
