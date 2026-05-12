import Foundation

enum FixtureClientFactory {
    static func homeClient() -> HomeClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureHomeClient() : HomeClient()
    }

    static func pickClient() -> PickClientProtocol {
        FixtureFileResolver.usesFixtures ? FixturePickClient() : PickClient()
    }

    static func orderClient() -> OrderClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureOrderClient() : OrderClient()
    }

    static func communityClient() -> CommunityClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureCommunityClient() : CommunityClient()
    }

    static func profileClient() -> ProfileClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureProfileClient() : ProfileClient()
    }

    static func chatClient() -> ChatClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureChatClient() : ChatClient()
    }

    static func storeDetailClient() -> StoreDetailClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureStoreDetailClient() : StoreDetailClient()
    }

    static func reviewClient() -> ReviewClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureReviewClient() : ReviewClient()
    }

    static func videoClient() -> VideoClientProtocol {
        FixtureFileResolver.usesFixtures ? FixtureVideoClient() : VideoClient()
    }
}

final class FixtureHomeClient: HomeClientProtocol {
    func fetchBanners() async throws -> [Banner] {
        try FixtureLoader.decode(from: "home/banners")
    }

    func fetchPopularStores(category: String?) async throws -> [StoreSummary] {
        if let category {
            if let stores: [StoreSummary] = FixtureLoader.decodeIfPresent(from: "home/popular_stores_\(fixtureSafeName(category))") {
                return stores
            }
            return try FixtureLoader.decode(from: "home/popular_stores")
        }
        return try FixtureLoader.decode(from: "home/popular_stores")
    }

    func fetchPopularSearches() async throws -> [String] {
        try FixtureLoader.decode(from: "home/popular_searches")
    }

    func fetchNearbyStores(
        longitude: Double,
        latitude: Double,
        orderBy: String,
        category: String?,
        next: String?
    ) async throws -> HomeStorePage {
        try FixtureLoader.decode(from: "home/nearby_stores")
    }

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        likeStatus
    }
}

final class FixturePickClient: PickClientProtocol {
    func fetchNearbyStores(longitude: Double, latitude: Double, orderBy: String) async throws -> [StoreSummary] {
        try FixtureLoader.decode(from: "pick/nearby_stores")
    }
}

final class FixtureOrderClient: OrderClientProtocol {
    func fetchOrders() async throws -> [Order] {
        try FixtureLoader.decode(from: "order/orders")
    }

    func updateOrderStatus(orderCode: String, nextStatus: String) async throws {
        throw FixtureError.unsupportedWriteOperation
    }
}

final class FixtureCommunityClient: CommunityClientProtocol {
    func fetchBanners() async throws -> [Banner] {
        try FixtureLoader.decode(from: "community/banners")
    }

    func uploadFiles(parts: [MultipartData]) async throws -> [String] {
        throw FixtureError.unsupportedWriteOperation
    }

    func createPost(_ request: CreatePostRequest) async throws -> PostDetail {
        throw FixtureError.unsupportedWriteOperation
    }

    func fetchGeolocationPosts(
        longitude: Double,
        latitude: Double,
        category: String?,
        orderBy: String,
        next: String?,
        limit: Int?
    ) async throws -> PostPage {
        try FixtureLoader.decode(from: "community/geolocation_posts")
    }

    func searchPosts(title: String) async throws -> [PostSummary] {
        try FixtureLoader.decodeIfPresent(from: "community/search_posts") ?? []
    }

    func fetchPostDetail(postId: String) async throws -> PostDetail {
        if let exact: PostDetail = FixtureLoader.decodeIfPresent(from: "community/post_detail_\(fixtureSafeName(postId))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "community", prefix: "post_detail_"))
    }

    func updatePost(postId: String, _ request: UpdatePostRequest) async throws -> PostDetail {
        throw FixtureError.unsupportedWriteOperation
    }

    func deletePost(postId: String) async throws {
        throw FixtureError.unsupportedWriteOperation
    }

    func toggleLike(postId: String, likeStatus: Bool) async throws -> Bool {
        likeStatus
    }

    func fetchUserPosts(userId: String, category: String?, next: String?, limit: Int?) async throws -> PostPage {
        try FixtureLoader.decode(from: "community/geolocation_posts")
    }

    func fetchLikedPosts(category: String?, next: String?, limit: Int?) async throws -> PostPage {
        try FixtureLoader.decode(from: "community/geolocation_posts")
    }

    func createComment(postId: String, parentCommentId: String?, content: String) async throws -> PostComment {
        throw FixtureError.unsupportedWriteOperation
    }

    func updateComment(postId: String, commentId: String, content: String) async throws -> PostComment {
        throw FixtureError.unsupportedWriteOperation
    }

    func deleteComment(postId: String, commentId: String) async throws {
        throw FixtureError.unsupportedWriteOperation
    }
}

final class FixtureProfileClient: ProfileClientProtocol {
    func fetchMyProfile() async throws -> MyProfile {
        try FixtureLoader.decode(from: "profile/my_profile")
    }

    func updateMyProfile(nick: String?, phoneNum: String?, profileImage: String?) async throws -> MyProfile {
        throw FixtureError.unsupportedWriteOperation
    }

    func uploadProfileImage(data: Data, fileName: String, mimeType: String) async throws -> String? {
        throw FixtureError.unsupportedWriteOperation
    }

    func logout() async throws {}
}

final class FixtureChatClient: ChatClientProtocol {
    func createOrFetchRoom(opponentUserID: String) async throws -> ChatRoom {
        throw FixtureError.unsupportedWriteOperation
    }

    func fetchRooms() async throws -> [ChatRoom] {
        try FixtureLoader.decode(from: "chat/rooms")
    }

    func fetchMessages(roomID: String, next: String?) async throws -> [ChatMessage] {
        if let exact: [ChatMessage] = FixtureLoader.decodeIfPresent(from: "chat/messages_\(fixtureSafeName(roomID))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "chat", prefix: "messages_"))
    }

    func sendMessage(roomID: String, content: String, files: [String]) async throws -> ChatMessage {
        throw FixtureError.unsupportedWriteOperation
    }

    func uploadFiles(roomID: String, parts: [MultipartData]) async throws -> [String] {
        throw FixtureError.unsupportedWriteOperation
    }
}

final class FixtureStoreDetailClient: StoreDetailClientProtocol {
    func fetchStoreDetail(storeId: String) async throws -> StoreDetail {
        if let exact: StoreDetail = FixtureLoader.decodeIfPresent(from: "store/detail_\(fixtureSafeName(storeId))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "store", prefix: "detail_"))
    }

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        likeStatus
    }
}

final class FixtureReviewClient: ReviewClientProtocol {
    func uploadFiles(storeId: String, parts: [MultipartData]) async throws -> [String] {
        throw FixtureError.unsupportedWriteOperation
    }

    func createReview(storeId: String, request: CreateReviewRequest) async throws -> ReviewDetail {
        throw FixtureError.unsupportedWriteOperation
    }

    func fetchReviews(storeId: String, next: String?, limit: Int?, orderBy: String?) async throws -> ReviewPage {
        if let exact: ReviewPage = FixtureLoader.decodeIfPresent(from: "review/reviews_\(fixtureSafeName(storeId))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "review", prefix: "reviews_"))
    }

    func fetchReview(storeId: String, reviewId: String) async throws -> ReviewDetail {
        throw FixtureError.unsupportedWriteOperation
    }

    func updateReview(storeId: String, reviewId: String, request: UpdateReviewRequest) async throws -> ReviewDetail {
        throw FixtureError.unsupportedWriteOperation
    }

    func deleteReview(storeId: String, reviewId: String) async throws {
        throw FixtureError.unsupportedWriteOperation
    }

    func fetchRatings(storeId: String) async throws -> [ReviewRating] {
        if let exact: [ReviewRating] = FixtureLoader.decodeIfPresent(from: "review/ratings_\(fixtureSafeName(storeId))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "review", prefix: "ratings_"))
    }
}

final class FixtureVideoClient: VideoClientProtocol {
    func fetchVideos(next: String?, limit: Int?) async throws -> VideoPage {
        try FixtureLoader.decode(from: "video/videos")
    }

    func fetchStream(videoId: String) async throws -> StreamInfo {
        if let exact: StreamInfo = FixtureLoader.decodeIfPresent(from: "video/stream_\(fixtureSafeName(videoId))") {
            return exact
        }
        return try FixtureLoader.decode(from: firstFixturePath(in: "video", prefix: "stream_"))
    }

    func toggleLike(videoId: String, likeStatus: Bool) async throws -> Bool {
        likeStatus
    }
}

private func fixtureSafeName(_ value: String) -> String {
    let sanitized = value
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: "-")
        .lowercased()
    return sanitized.isEmpty ? "item" : sanitized
}

private func firstFixturePath(in directory: String, prefix: String) throws -> String {
    let subdirectory = "Fixtures/data/\(directory)"
    let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: subdirectory) ?? []
    guard let url = urls.first(where: { $0.deletingPathExtension().lastPathComponent.hasPrefix(prefix) }) else {
        throw FixtureError.missingFixture("\(directory)/\(prefix)*")
    }
    return "\(directory)/\(url.deletingPathExtension().lastPathComponent)"
}
