import Foundation

// MARK: - Pagination Wrapper

struct PostPage {
    let posts: [PostSummary]
    let nextCursor: String?
}

// MARK: - Protocol

protocol CommunityClientProtocol {
    func uploadFiles(parts: [MultipartData]) async throws -> [String]
    func createPost(_ request: CreatePostRequest) async throws -> PostDetail
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage
    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail
    func deletePost(postId: String) async throws
}

// MARK: - Request DTOs

struct CreatePostRequest: Encodable {
    let category: String
    let title: String
    let content: String
    let store_id: String?
    let latitude: Double
    let longitude: Double
    let files: [String]?
}

struct UpdatePostRequest: Encodable {
    let category: String?
    let title: String?
    let content: String?
    let store_id: String?
    let latitude: Double?
    let longitude: Double?
    let files: [String]?
}

// MARK: - Endpoints

private enum CommunityEndpoint: Endpoint {
    case uploadFiles(parts: [MultipartData])
    case createPost(CreatePostRequest)
    case geolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?)
    case updatePost(postId: String, UpdatePostRequest)
    case deletePost(postId: String)

    var path: String {
        switch self {
        case .uploadFiles:                       return "/v1/posts/files"
        case .createPost:                        return "/v1/posts"
        case .geolocationPosts:                  return "/v1/posts/geolocation"
        case .updatePost(let id, _):             return "/v1/posts/\(id)"
        case .deletePost(let id):                return "/v1/posts/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .uploadFiles, .createPost:
            return .post
        case .updatePost:
            return .put
        case .deletePost:
            return .delete
        case .geolocationPosts:
            return .get
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .uploadFiles(let parts):
            return .multipart(parts)
        case .createPost(let body):
            return .body(body)
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
        case .updatePost(_, let body):
            return .body(body)
        case .deletePost:
            return .none
        }
    }
}

// MARK: - Private Response DTOs

private struct PostsPageResponse: Decodable {
    let data: [PostSummary]
    let next_cursor: String
}

private struct FileUploadResponse: Decodable {
    let files: [String]
}

// MARK: - Real Implementation

final class CommunityClient: CommunityClientProtocol {

    func uploadFiles(parts: [MultipartData]) async throws -> [String] {
        let response: FileUploadResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.uploadFiles(parts: parts)
        )
        return response.files
    }

    func createPost(_ request: CreatePostRequest) async throws -> PostDetail {
        try await NetworkManager.shared.request(CommunityEndpoint.createPost(request))
    }

    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage {
        let response: PostsPageResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.geolocationPosts(longitude: longitude, latitude: latitude, category: category, orderBy: orderBy, next: next, limit: limit)
        )
        let nextCursor = response.next_cursor == "0" ? nil : response.next_cursor
        return PostPage(posts: response.data, nextCursor: nextCursor)
    }

    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail {
        try await NetworkManager.shared.request(CommunityEndpoint.updatePost(postId: postId, request))
    }

    func deletePost(postId: String) async throws {
        try await NetworkManager.shared.requestWithoutResponse(CommunityEndpoint.deletePost(postId: postId))
    }
}

// MARK: - Mock

final class MockCommunityClient: CommunityClientProtocol {
    var uploadFilesResult: Result<[String], Error> = .success([])
    var createPostResult: Result<PostDetail, Error> = .failure(MockError.notImplemented)
    var fetchGeolocationPostsResult: Result<PostPage, Error> = .success(PostPage(posts: [], nextCursor: nil))
    var updatePostResult: Result<PostDetail, Error> = .failure(MockError.notImplemented)
    var deletePostResult: Result<Void, Error> = .success(())

    enum MockError: Error { case notImplemented }

    func uploadFiles(parts: [MultipartData]) async throws -> [String] { try uploadFilesResult.get() }
    func createPost(_ request: CreatePostRequest) async throws -> PostDetail { try createPostResult.get() }
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage { try fetchGeolocationPostsResult.get() }
    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail { try updatePostResult.get() }
    func deletePost(postId: String) async throws { try deletePostResult.get() }
}
