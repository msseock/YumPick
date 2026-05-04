import Foundation

@Observable
final class CommunityPostDetailViewModel {
    var post: PostDetail? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var showDeleteConfirm = false
    private var isLikeRequestInFlight = false

    var isOwner: Bool {
        guard let post else { return false }
        return post.creator.user_id == CurrentUser.id
    }

    private(set) var didDeletePost = false

    private let client: CommunityClientProtocol

    init(client: CommunityClientProtocol = CommunityClient()) {
        self.client = client
    }

    func loadDetail(postId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            post = try await client.fetchPostDetail(postId: postId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike() async {
        guard !isLikeRequestInFlight else { return }
        guard let post else { return }

        let currentLiked = PostLikeStateStore.shared.isLiked(for: post.post_id, fallback: post.is_like)
        let newLiked = !currentLiked

        isLikeRequestInFlight = true
        defer { isLikeRequestInFlight = false }

        PostLikeStateStore.shared.update(postId: post.post_id, isLiked: newLiked)
        updatePostLikeState(isLiked: newLiked, previousLiked: currentLiked)

        do {
            let confirmed = try await client.toggleLike(postId: post.post_id, likeStatus: newLiked)
            PostLikeStateStore.shared.update(postId: post.post_id, isLiked: confirmed)
            updatePostLikeState(isLiked: confirmed)
        } catch {
            PostLikeStateStore.shared.update(postId: post.post_id, isLiked: currentLiked)
            updatePostLikeState(isLiked: currentLiked, previousLiked: newLiked)
        }
    }

    private func updatePostLikeState(isLiked: Bool, previousLiked: Bool? = nil) {
        guard let current = post else { return }
        let currentLiked = previousLiked ?? current.is_like
        let delta: Double
        if currentLiked == isLiked {
            delta = 0
        } else {
            delta = isLiked ? 1 : -1
        }

        post = PostDetail(
            post_id: current.post_id, category: current.category, title: current.title,
            content: current.content, store: current.store, geolocation: current.geolocation,
            creator: current.creator, files: current.files,
            is_like: isLiked, like_count: max(0, current.like_count + delta),
            comments: current.comments, createdAt: current.createdAt, updatedAt: current.updatedAt
        )
    }

    func deletePost() async {
        guard let post else { return }
        do {
            try await client.deletePost(postId: post.post_id)
            didDeletePost = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
