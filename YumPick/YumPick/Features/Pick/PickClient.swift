import Foundation

// MARK: - Protocol

protocol PickClientProtocol {
    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary]
}

// MARK: - Endpoints

private enum PickEndpoint: Endpoint {
    case nearbyStores(longitude: Double, latitude: Double, orderBy: String)

    var path: String { "/v1/stores" }
    var method: HTTPMethod { .get }

    var parameters: RequestParameters {
        switch self {
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

private struct NearbyStoresResponse: Decodable {
    let data: [StoreSummary]
    let next_cursor: String
}

// MARK: - Real Implementation

final class PickClient: PickClientProtocol {
    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary] {
        let response: NearbyStoresResponse = try await NetworkManager.shared.request(
            PickEndpoint.nearbyStores(longitude: longitude, latitude: latitude, orderBy: orderBy)
        )
        return response.data
    }
}

// MARK: - Mock

final class MockPickClient: PickClientProtocol {
    var fetchNearbyStoresResult: Result<[StoreSummary], Error> = .success([])

    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary] {
        try fetchNearbyStoresResult.get()
    }
}
