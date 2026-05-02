import Foundation

enum HomeStoreCache {
    static var popularStores: [StoreSummary]? {
        get { UserDefaultsManager.shared.homeCachedPopularStores }
        set { UserDefaultsManager.shared.homeCachedPopularStores = newValue }
    }

    static var nearbyFirstPage: HomeNearbyFirstPageCache? {
        get { UserDefaultsManager.shared.homeCachedNearbyFirstPage }
        set { UserDefaultsManager.shared.homeCachedNearbyFirstPage = newValue }
    }

    static func applyLikeUpdate(storeId: String, isLiked: Bool, pickCountDelta: Int) {
        if var stores = popularStores,
           let idx = stores.firstIndex(where: { $0.store_id == storeId })
        {
            stores[idx] = stores[idx].applyingLikeUpdate(isLiked: isLiked, pickCountDelta: pickCountDelta)
            popularStores = stores
        }

        if let page = nearbyFirstPage,
           let idx = page.stores.firstIndex(where: { $0.store_id == storeId })
        {
            var stores = page.stores
            stores[idx] = stores[idx].applyingLikeUpdate(isLiked: isLiked, pickCountDelta: pickCountDelta)
            nearbyFirstPage = HomeNearbyFirstPageCache(
                stores: stores,
                nextCursor: page.nextCursor,
                sort: page.sort
            )
        }
    }

    static func clear() {
        popularStores = nil
        nearbyFirstPage = nil
    }
}

private extension StoreSummary {
    func applyingLikeUpdate(isLiked: Bool, pickCountDelta: Int) -> StoreSummary {
        StoreSummary(
            store_id: store_id,
            category: category,
            name: name,
            close: close,
            store_image_urls: store_image_urls,
            is_picchelin: is_picchelin,
            is_pick: isLiked,
            pick_count: (pick_count ?? 0) + pickCountDelta,
            hashTags: hashTags,
            total_rating: total_rating,
            total_order_count: total_order_count,
            total_review_count: total_review_count,
            geolocation: geolocation,
            distance: distance,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
