import Foundation

// MARK: - Pagination Wrapper

struct PostPage {
    let posts: [PostSummary]
    let nextCursor: String?
}

// MARK: - Protocol

protocol CommunityClientProtocol {
    func fetchBanners() async throws -> [Banner]
    func uploadFiles(parts: [MultipartData]) async throws -> [String]
    func createPost(_ request: CreatePostRequest) async throws -> PostDetail
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage
    func searchPosts(title: String) async throws -> [PostSummary]
    func fetchPostDetail(postId: String) async throws -> PostDetail
    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail
    func deletePost(postId: String) async throws
    func toggleLike(postId: String, likeStatus: Bool) async throws -> Bool
    func fetchUserPosts(userId: String, category: String?, next: String?, limit: Int?) async throws -> PostPage
    func fetchLikedPosts(category: String?, next: String?, limit: Int?) async throws -> PostPage
    func createComment(postId: String, parentCommentId: String?, content: String) async throws -> PostComment
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment
    func deleteComment(postId: String, commentId: String) async throws
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
    case banners
    case uploadFiles(parts: [MultipartData])
    case createPost(CreatePostRequest)
    case geolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?)
    case searchPosts(title: String)
    case postDetail(postId: String)
    case updatePost(postId: String, UpdatePostRequest)
    case deletePost(postId: String)
    case toggleLike(postId: String, likeStatus: Bool)
    case userPosts(userId: String, category: String?, next: String?, limit: Int?)
    case likedPosts(category: String?, next: String?, limit: Int?)
    case createComment(postId: String, parentCommentId: String?, content: String)
    case updateComment(postId: String, commentId: String, content: String)
    case deleteComment(postId: String, commentId: String)

    var path: String {
        switch self {
        case .banners:                           return "/v1/banners/main"
        case .uploadFiles:                       return "/v1/posts/files"
        case .createPost:                        return "/v1/posts"
        case .geolocationPosts:                  return "/v1/posts/geolocation"
        case .searchPosts:                       return "/v1/posts/search"
        case .postDetail(let id):                return "/v1/posts/\(id)"
        case .updatePost(let id, _):             return "/v1/posts/\(id)"
        case .deletePost(let id):                return "/v1/posts/\(id)"
        case .toggleLike(let id, _):             return "/v1/posts/\(id)/like"
        case .userPosts(let userId, _, _, _):    return "/v1/posts/users/\(userId)"
        case .likedPosts:                        return "/v1/posts/likes/me"
        case .createComment(let postId, _, _):   return "/v1/posts/\(postId)/comments"
        case .updateComment(let postId, let commentId, _): return "/v1/posts/\(postId)/comments/\(commentId)"
        case .deleteComment(let postId, let commentId):    return "/v1/posts/\(postId)/comments/\(commentId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .uploadFiles, .createPost, .toggleLike, .createComment:
            return .post
        case .updatePost, .updateComment:
            return .put
        case .deletePost, .deleteComment:
            return .delete
        default:
            return .get
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .banners:
            return .none
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
        case .searchPosts(let title):
            return .query(["title": title])
        case .postDetail, .deletePost, .deleteComment:
            return .none
        case .updatePost(_, let body):
            return .body(body)
        case .toggleLike(_, let status):
            return .body(LikeRequest(like_status: status))
        case .userPosts(_, let category, let next, let limit):
            var dict: [String: String] = [:]
            if let category { dict["category"] = category }
            if let next, !next.isEmpty { dict["next"] = next }
            if let limit { dict["limit"] = "\(limit)" }
            return .query(dict)
        case .likedPosts(let category, let next, let limit):
            var dict: [String: String] = [:]
            if let category { dict["category"] = category }
            if let next, !next.isEmpty { dict["next"] = next }
            if let limit { dict["limit"] = "\(limit)" }
            return .query(dict)
        case .createComment(_, let parentId, let content):
            return .body(CreateCommentRequest(content: content, parentCommentId: parentId))
        case .updateComment(_, _, let content):
            return .body(UpdateCommentRequest(content: content))
        }
    }
}

// MARK: - Private Response DTOs

private struct BannerListResponse: Decodable {
    let data: [Banner]
}

private struct PostsPageResponse: Decodable {
    let data: [PostSummary]
    let next_cursor: String
}

private struct PostSearchResponse: Decodable {
    let data: [PostSummary]
}

private struct FileUploadResponse: Decodable {
    let files: [String]
}

private struct LikeRequest: Encodable {
    let like_status: Bool
}

private struct LikeResponse: Decodable {
    let like_status: Bool
}

struct CreateCommentRequest: Encodable {
    let content: String
    let parentCommentId: String?

    enum CodingKeys: String, CodingKey {
        case content
        case parentCommentId = "parent_comment_id"
    }

    init(content: String, parentCommentId: String? = nil) {
        self.content = content
        self.parentCommentId = parentCommentId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        if let parentCommentId, !parentCommentId.isEmpty {
            try container.encode(parentCommentId, forKey: .parentCommentId)
        }
    }
}

private struct UpdateCommentRequest: Encodable {
    let content: String
}

// MARK: - Real Implementation

final class CommunityClient: CommunityClientProtocol {

    func fetchBanners() async throws -> [Banner] {
        let response: BannerListResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.banners
        )
        return response.data
    }

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

    func searchPosts(title: String) async throws -> [PostSummary] {
        let response: PostSearchResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.searchPosts(title: title)
        )
        return response.data
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        try await NetworkManager.shared.request(CommunityEndpoint.postDetail(postId: postId))
    }

    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail {
        try await NetworkManager.shared.request(CommunityEndpoint.updatePost(postId: postId, request))
    }

    func deletePost(postId: String) async throws {
        try await NetworkManager.shared.requestWithoutResponse(CommunityEndpoint.deletePost(postId: postId))
    }

    func toggleLike(postId: String, likeStatus: Bool) async throws -> Bool {
        let response: LikeResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.toggleLike(postId: postId, likeStatus: likeStatus)
        )
        return response.like_status
    }

    func fetchUserPosts(userId: String, category: String?, next: String?, limit: Int?) async throws -> PostPage {
        let response: PostsPageResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.userPosts(userId: userId, category: category, next: next, limit: limit)
        )
        let nextCursor = response.next_cursor == "0" ? nil : response.next_cursor
        return PostPage(posts: response.data, nextCursor: nextCursor)
    }

    func fetchLikedPosts(category: String?, next: String?, limit: Int?) async throws -> PostPage {
        let response: PostsPageResponse = try await NetworkManager.shared.request(
            CommunityEndpoint.likedPosts(category: category, next: next, limit: limit)
        )
        let nextCursor = response.next_cursor == "0" ? nil : response.next_cursor
        return PostPage(posts: response.data, nextCursor: nextCursor)
    }

    func createComment(postId: String, parentCommentId: String?, content: String) async throws -> PostComment {
        try await NetworkManager.shared.request(
            CommunityEndpoint.createComment(postId: postId, parentCommentId: parentCommentId, content: content)
        )
    }

    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment {
        try await NetworkManager.shared.request(
            CommunityEndpoint.updateComment(postId: postId, commentId: commentId, content: content)
        )
    }

    func deleteComment(postId: String, commentId: String) async throws {
        try await NetworkManager.shared.requestWithoutResponse(
            CommunityEndpoint.deleteComment(postId: postId, commentId: commentId)
        )
    }
}

// MARK: - Mock

final class MockCommunityClient: CommunityClientProtocol {
    var fetchBannersResult: Result<[Banner], Error> = .success([])
    var uploadFilesResult: Result<[String], Error> = .success([])
    var createPostResult: Result<PostDetail, Error> = .failure(MockError.notImplemented)
    var fetchGeolocationPostsResult: Result<PostPage, Error> = .success(PostPage(posts: [], nextCursor: nil))
    var searchPostsResult: Result<[PostSummary], Error> = .success([])
    var fetchPostDetailResult: Result<PostDetail, Error> = .failure(MockError.notImplemented)
    var updatePostResult: Result<PostDetail, Error> = .failure(MockError.notImplemented)
    var deletePostResult: Result<Void, Error> = .success(())
    var toggleLikeResult: Result<Bool, Error> = .success(true)
    var fetchUserPostsResult: Result<PostPage, Error> = .success(PostPage(posts: [], nextCursor: nil))
    var fetchLikedPostsResult: Result<PostPage, Error> = .success(PostPage(posts: [], nextCursor: nil))
    var createCommentResult: Result<PostComment, Error> = .failure(MockError.notImplemented)
    var updateCommentResult: Result<PostComment, Error> = .failure(MockError.notImplemented)
    var deleteCommentResult: Result<Void, Error> = .success(())
    private(set) var createCommentRequests: [(postId: String, parentCommentId: String?, content: String)] = []

    enum MockError: Error { case notImplemented }

    func fetchBanners() async throws -> [Banner] { try fetchBannersResult.get() }
    func uploadFiles(parts: [MultipartData]) async throws -> [String] { try uploadFilesResult.get() }
    func createPost(_ request: CreatePostRequest) async throws -> PostDetail { try createPostResult.get() }
    func fetchGeolocationPosts(longitude: Double, latitude: Double, category: String?, orderBy: String, next: String?, limit: Int?) async throws -> PostPage { try fetchGeolocationPostsResult.get() }
    func searchPosts(title: String) async throws -> [PostSummary] { try searchPostsResult.get() }
    func fetchPostDetail(postId: String) async throws -> PostDetail { try fetchPostDetailResult.get() }
    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail { try updatePostResult.get() }
    func deletePost(postId: String) async throws { try deletePostResult.get() }
    func toggleLike(postId: String, likeStatus: Bool) async throws -> Bool { try toggleLikeResult.get() }
    func fetchUserPosts(userId: String, category: String?, next: String?, limit: Int?) async throws -> PostPage { try fetchUserPostsResult.get() }
    func fetchLikedPosts(category: String?, next: String?, limit: Int?) async throws -> PostPage { try fetchLikedPostsResult.get() }
    func createComment(postId: String, parentCommentId: String?, content: String) async throws -> PostComment {
        createCommentRequests.append((postId: postId, parentCommentId: parentCommentId, content: content))
        return try createCommentResult.get()
    }
    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment { try updateCommentResult.get() }
    func deleteComment(postId: String, commentId: String) async throws { try deleteCommentResult.get() }
}
