import Foundation

// MARK: - Protocol

protocol HomeClientProtocol {
    func fetchBanners() async throws -> [Banner]
    func fetchPopularStores(category: String?) async throws -> [StoreSummary]
    func fetchPopularSearches() async throws -> [String]
    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary]
}

// MARK: - Endpoints

private enum HomeEndpoint: Endpoint {
    case banners
    case popularStores(category: String?)
    case popularSearches
    case nearbyStores(longitude: Double, latitude: Double, orderBy: String)

    var path: String {
        switch self {
        case .banners: return "/v1/banners/main"
        case .popularStores: return "/v1/stores/popular-stores"
        case .popularSearches: return "/v1/stores/searches-popular"
        case .nearbyStores: return "/v1/stores"
        }
    }

    var method: HTTPMethod { .get }

    var parameters: RequestParameters {
        switch self {
        case .banners, .popularSearches:
            return .none
        case .popularStores(let category):
            var dict: [String: String] = [:]
            if let category { dict["category"] = category }
            return dict.isEmpty ? .none : .query(dict)
        case .nearbyStores(let longitude, let latitude, let orderBy):
            return .query([
                "longitude": "\(longitude)",
                "latitude": "\(latitude)",
                "order_by": orderBy
            ])
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
    let next_cursor: String
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

    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary] {
        let response: NearbyStoresResponse = try await NetworkManager.shared
            .request(HomeEndpoint.nearbyStores(longitude: longitude, latitude: latitude, orderBy: orderBy))
        return response.data
    }
}

// MARK: - Mock

final class MockHomeClient: HomeClientProtocol {
    var fetchBannersResult: Result<[Banner], Error> = .success([])
    var fetchPopularStoresResult: Result<[StoreSummary], Error> = .success([])
    var fetchPopularSearchesResult: Result<[String], Error> = .success([])
    var fetchNearbyStoresResult: Result<[StoreSummary], Error> = .success([])

    func fetchBanners() async throws -> [Banner] {
        try fetchBannersResult.get()
    }

    func fetchPopularStores(category: String?) async throws -> [StoreSummary] {
        try fetchPopularStoresResult.get()
    }

    func fetchPopularSearches() async throws -> [String] {
        try fetchPopularSearchesResult.get()
    }

    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary] {
        try fetchNearbyStoresResult.get()
    }
}
