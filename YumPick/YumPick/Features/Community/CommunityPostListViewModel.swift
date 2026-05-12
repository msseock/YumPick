import Foundation

enum PostListMode {
    case userPosts(userId: String)
    case likedByMe
}

@Observable
final class CommunityPostListViewModel {
    var posts: [PostSummary] = []
    var isLoading = false
    var isPageLoading = false
    var errorMessage: String? = nil

    private(set) var nextCursor: String? = nil
    private(set) var hasMore = true
    private var loadedCursors: Set<String> = []

    var canLoadMore: Bool { hasMore && !isPageLoading }

    private let mode: PostListMode
    private let client: CommunityClientProtocol

    init(mode: PostListMode, client: CommunityClientProtocol = FixtureClientFactory.communityClient()) {
        self.mode = mode
        self.client = client
    }

    func fetchPosts(reset: Bool = true) async {
        guard reset || canLoadMore else { return }
        guard !isPageLoading else { return }

        let requestedCursor = reset ? nil : nextCursor
        if !reset {
            guard let requestedCursor else { hasMore = false; return }
            guard !loadedCursors.contains(requestedCursor) else {
                hasMore = false; nextCursor = nil; return
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

        do {
            let page = try await fetchPage(cursor: requestedCursor)

            if let requestedCursor { loadedCursors.insert(requestedCursor) }

            if reset { posts = page.posts } else { posts.append(contentsOf: page.posts) }

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

    private func fetchPage(cursor: String?) async throws -> PostPage {
        switch mode {
        case .userPosts(let userId):
            return try await client.fetchUserPosts(userId: userId, category: nil, next: cursor, limit: nil)
        case .likedByMe:
            return try await client.fetchLikedPosts(category: nil, next: cursor, limit: nil)
        }
    }
}
