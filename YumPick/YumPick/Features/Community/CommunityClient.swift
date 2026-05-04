import Foundation

// MARK: - Pagination Wrapper

struct PostPage {
    let posts: [PostSummary]
    let nextCursor: String?
}

// MARK: - Protocol

protocol CommunityClientProtocol {
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage
}

// MARK: - Endpoints

private enum CommunityEndpoint: Endpoint {
    case geolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?)

    var path: String { "/v1/posts/geolocation" }
    var method: HTTPMethod { .get }

    var parameters: RequestParameters {
        switch self {
        case .geolocationPosts(let longitude, let latitude, let category, let orderBy, let next, let limit):
            var dict: [String: String] = [
                "longitude": "\(longitude)",
                "latitude": "\(latitude)",
                "order_by": orderBy
            ]
            if let category { dict["category"] = category }
            if let next, !next.isEmpty { dict["next"] = next }
            if let limit { dict["limit"] = "\(limit)" }
            return .query(dict)
        }
    }
}

// MARK: - Private Response DTOs

private struct PostsPageResponse: Decodable {
    let data: [PostSummary]
    let next_cursor: String
}

// MARK: - Real Implementation

final class CommunityClient: CommunityClientProtocol {
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage {
        let response: PostsPageResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.geolocationPosts(longitude: longitude, latitude: latitude, category: category, orderBy: orderBy, next: next, limit: limit)
        )
        let nextCursor = response.next_cursor == "0" ? nil : response.next_cursor
        return PostPage(posts: response.data, nextCursor: nextCursor)
    }
}

// MARK: - Mock

final class MockCommunityClient: CommunityClientProtocol {
    var fetchGeolocationPostsResult: Result<PostPage, Error> = .success(PostPage(posts: [], nextCursor: nil))

    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage {
        try fetchGeolocationPostsResult.get()
    }
}
