import Foundation

// MARK: - Protocol

protocol CommunityClientProtocol {
    func fetchPosts(longitude: Double, latitude: Double, category: String?, orderBy: String) async throws -> [PostSummary]
}

// MARK: - Endpoints

private enum CommunityEndpoint: Endpoint {
    case posts(longitude: Double, latitude: Double, category: String?, orderBy: String)

    var path: String { "/v1/posts/geolocation" }
    var method: HTTPMethod { .get }

    var parameters: RequestParameters {
        switch self {
        case .posts(let longitude, let latitude, let category, let orderBy):
            var dict: [String: String] = [
                "longitude": "\(longitude)",
                "latitude": "\(latitude)",
                "order_by": orderBy
            ]
            if let category { dict["category"] = category }
            return .query(dict)
        }
    }
}

// MARK: - Response DTOs

private struct PostsResponse: Decodable {
    let data: [PostSummary]
    let next_cursor: String
}

// MARK: - Real Implementation

final class CommunityClient: CommunityClientProtocol {
    func fetchPosts(longitude: Double, latitude: Double, category: String?, orderBy: String) async throws -> [PostSummary] {
        let response: PostsResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.posts(longitude: longitude, latitude: latitude, category: category, orderBy: orderBy)
        )
        return response.data
    }
}

// MARK: - Mock

final class MockCommunityClient: CommunityClientProtocol {
    var fetchPostsResult: Result<[PostSummary], Error> = .success([])

    func fetchPosts(longitude: Double, latitude: Double, category: String?, orderBy: String) async throws -> [PostSummary] {
        try fetchPostsResult.get()
    }
}
