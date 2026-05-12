import Foundation

// MARK: - Protocol

protocol HomeClientProtocol {
    func fetchBanners() async throws -> [Banner]
    func fetchPopularStores(category: String?) async throws -> [StoreSummary]
    func fetchPopularSearches() async throws -> [String]
    func fetchNearbyStores(
        longitude: Double,
        latitude: Double,
        orderBy: String,
        category: String?,
        next: String?
    ) async throws -> HomeStorePage
    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool
}

struct HomeStorePage: Codable {
    let stores: [StoreSummary]
    let nextCursor: String?
}

// MARK: - Endpoints

private struct LikeRequestBody: Encodable {
    let like_status: Bool
}

private struct LikeStoreResponse: Decodable {
    let like_status: Bool
}

private enum HomeEndpoint: Endpoint {
    case banners
    case popularStores(category: String?)
    case popularSearches
    case nearbyStores(longitude: Double, latitude: Double, orderBy: String, category: String?, next: String?)
    case like(storeId: String, likeStatus: Bool)

    var path: String {
        switch self {
        case .banners: return "/v1/banners/main"
        case .popularStores: return "/v1/stores/popular-stores"
        case .popularSearches: return "/v1/stores/searches-popular"
        case .nearbyStores: return "/v1/stores"
        case .like(let storeId, _): return "/v1/stores/\(storeId)/like"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .like: return .post
        default: return .get
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .banners, .popularSearches:
            return .none
        case .popularStores(let category):
            var dict: [String: String] = [:]
            if let category { dict["category"] = category }
            return dict.isEmpty ? .none : .query(dict)
        case .nearbyStores(let longitude, let latitude, let orderBy, let category, let next):
            var dict = [
                "longitude": "\(longitude)",
                "latitude": "\(latitude)",
                "order_by": orderBy
            ]
            if let category, !category.isEmpty {
                dict["category"] = category
            }
            if let next, !next.isEmpty {
                dict["next"] = next
            }
            return .query(dict)
        case .like(_, let likeStatus):
            return .body(LikeRequestBody(like_status: likeStatus))
        }
    }
}

// MARK: - Response DTOs

private struct BannerListResponse: Decodable {
    let data: [Banner]
}

private struct PopularStoresResponse: Decodable {
    let data: [StoreSummary]
}

private struct PopularSearchesResponse: Decodable {
    let data: [String]
}

private struct NearbyStoresResponse: Decodable {
    let data: [StoreSummary]
    let next_cursor: String?
}

// MARK: - Real Implementation

final class HomeClient: HomeClientProtocol {
    func fetchBanners() async throws -> [Banner] {
        let response: BannerListResponse = try await NetworkManager.shared
            .request(HomeEndpoint.banners)
        return response.data
    }

    func fetchPopularStores(category: String?) async throws -> [StoreSummary] {
        let response: PopularStoresResponse = try await NetworkManager.shared
            .request(HomeEndpoint.popularStores(category: category))
        return response.data
    }

    func fetchPopularSearches() async throws -> [String] {
        let response: PopularSearchesResponse = try await NetworkManager.shared
            .request(HomeEndpoint.popularSearches)
        return response.data
    }

    func fetchNearbyStores(
        longitude: Double,
        latitude: Double,
        orderBy: String,
        category: String?,
        next: String?
    ) async throws -> HomeStorePage {
        let response: NearbyStoresResponse = try await NetworkManager.shared
            .request(HomeEndpoint.nearbyStores(
                longitude: longitude,
                latitude: latitude,
                orderBy: orderBy,
                category: category,
                next: next
            ))
        return HomeStorePage(
            stores: response.data,
            nextCursor: response.next_cursor?.nilIfEmpty
        )
    }

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        let response: LikeStoreResponse = try await NetworkManager.shared
            .request(HomeEndpoint.like(storeId: storeId, likeStatus: likeStatus))
        return response.like_status
    }
}

// MARK: - Mock

final class MockHomeClient: HomeClientProtocol {
    var fetchBannersResult: Result<[Banner], Error> = .success([])
    var fetchPopularStoresResult: Result<[StoreSummary], Error> = .success([])
    var fetchPopularSearchesResult: Result<[String], Error> = .success([])
    var fetchNearbyStoresResult: Result<HomeStorePage, Error> = .success(
        HomeStorePage(stores: [], nextCursor: nil)
    )

    func fetchBanners() async throws -> [Banner] {
        try fetchBannersResult.get()
    }

    func fetchPopularStores(category: String?) async throws -> [StoreSummary] {
        try fetchPopularStoresResult.get()
    }

    func fetchPopularSearches() async throws -> [String] {
        try fetchPopularSearchesResult.get()
    }

    func fetchNearbyStores(
        longitude: Double,
        latitude: Double,
        orderBy: String,
        category: String?,
        next: String?
    ) async throws -> HomeStorePage {
        try fetchNearbyStoresResult.get()
    }

    var toggleLikeResult: Result<Bool, Error> = .success(true)

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        try toggleLikeResult.get()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
