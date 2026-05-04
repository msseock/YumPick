import Foundation

enum CommunityOrder: String, CaseIterable {
    case latest = "createdAt"
    case popular = "likes"

    var label: String {
        switch self {
        case .latest:  return "최신순"
        case .popular: return "인기순"
        }
    }
}

@Observable
final class CommunityViewModel {
    var posts: [PostSummary] = []
    var isLoading = false
    var isPageLoading = false
    var errorMessage: String? = nil

    var selectedCategory: String? = nil
    var orderBy: CommunityOrder = .latest

    private(set) var nextCursor: String? = nil
    private(set) var hasMore = true
    private var loadedCursors: Set<String> = []
    private var likeRequestPostIds: Set<String> = []

    var canLoadMore: Bool { hasMore && !isPageLoading }

    private let client: CommunityClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: CommunityClientProtocol = CommunityClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func fetchPosts(reset: Bool = true) async {
        guard reset || canLoadMore else { return }
        guard !isPageLoading else { return }

        let requestedCursor = reset ? nil : nextCursor
        if !reset {
            guard let requestedCursor else {
                hasMore = false
                return
            }
            guard !loadedCursors.contains(requestedCursor) else {
                hasMore = false
                nextCursor = nil
                return
            }
        }

        if reset {
            isLoading = true
            posts = []
            nextCursor = nil
            hasMore = true
            loadedCursors.removeAll()
        }

        isPageLoading = true
        defer {
            isPageLoading = false
            if reset { isLoading = false }
        }

        let geo = await locationManager.currentLocation() ?? Geolocation(longitude: 126.9780, latitude: 37.5665)
        do {
            let page = try await client.fetchGeolocationPosts(
                longitude: geo.longitude,
                latitude: geo.latitude,
                category: selectedCategory,
                orderBy: orderBy.rawValue,
                next: requestedCursor,
                limit: nil
            )

            if let requestedCursor {
                loadedCursors.insert(requestedCursor)
            }

            if reset {
                posts = page.posts
            } else {
                posts.append(contentsOf: page.posts)
            }

            if let cursor = page.nextCursor, !cursor.isEmpty, !loadedCursors.contains(cursor) {
                nextCursor = cursor
                hasMore = true
            } else {
                nextCursor = nil
                hasMore = false
            }
        } catch {
            errorMessage = error.localizedDescription
            hasMore = false
        }
    }

    func loadMore() async {
        await fetchPosts(reset: false)
    }

    func toggleLike(postId: String) async {
        guard !likeRequestPostIds.contains(postId) else { return }
        guard let original = posts.first(where: { $0.post_id == postId }) else { return }

        likeRequestPostIds.insert(postId)
        defer { likeRequestPostIds.remove(postId) }

        let currentLiked = PostLikeStateStore.shared.isLiked(for: postId, fallback: original.is_like)
        let newLiked = !currentLiked

        PostLikeStateStore.shared.update(postId: postId, isLiked: newLiked)
        updateVisiblePostLikeState(postId: postId, isLiked: newLiked, previousLiked: currentLiked)

        do {
            let confirmedLiked = try await client.toggleLike(postId: postId, likeStatus: newLiked)
            PostLikeStateStore.shared.update(postId: postId, isLiked: confirmedLiked)
            updateVisiblePostLikeState(postId: postId, isLiked: confirmedLiked)
        } catch {
            PostLikeStateStore.shared.update(postId: postId, isLiked: currentLiked)
            updateVisiblePostLikeState(postId: postId, isLiked: currentLiked, previousLiked: newLiked)
        }
    }

    private func updateVisiblePostLikeState(postId: String, isLiked: Bool, previousLiked: Bool? = nil) {
        guard let index = posts.firstIndex(where: { $0.post_id == postId }) else { return }

        let current = posts[index]
        let currentLiked = previousLiked ?? current.is_like
        let delta: Double
        if currentLiked == isLiked {
            delta = 0
        } else {
            delta = isLiked ? 1 : -1
        }

        posts[index] = PostSummary(
            post_id: current.post_id,
            category: current.category,
            title: current.title,
            content: current.content,
            store: current.store,
            geolocation: current.geolocation,
            creator: current.creator,
            files: current.files,
            is_like: isLiked,
            like_count: max(0, current.like_count + delta),
            createdAt: current.createdAt,
            updatedAt: current.updatedAt
        )
    }
}
