import Foundation

@Observable
final class CommunityPostDetailViewModel {
    var post: PostDetail? = nil
    var isLoading = true
    var errorMessage: String? = nil
    var alertMessage: String? = nil
    var showErrorAlert = false
    var showDeleteConfirm = false
    var showDeleteCommentConfirm = false
    private var isLikeRequestInFlight = false

    // 댓글 입력
    var commentInput: String = ""
    var replyTarget: PostComment? = nil
    var editingComment: (comment: PostComment, parentId: String?)? = nil
    var isCommentSubmitting = false

    private var pendingDeleteComment: (commentId: String, parentId: String?)? = nil

    var isOwner: Bool {
        guard let post else { return false }
        return post.creator.user_id == CurrentUser.id
    }

    func isCommentOwner(_ creatorId: String) -> Bool {
        creatorId == CurrentUser.id
    }

    private(set) var didDeletePost = false

    private let client: CommunityClientProtocol

    init(client: CommunityClientProtocol = CommunityClient()) {
        self.client = client
    }

    // MARK: - Post

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

    func deletePost() async {
        guard let post else { return }
        do {
            try await client.deletePost(postId: post.post_id)
            didDeletePost = true
        } catch {
            presentError(error.localizedDescription)
        }
    }

    // MARK: - Comment Input Actions

    func setReplyTarget(_ comment: PostComment) {
        replyTarget = comment
        editingComment = nil
        commentInput = ""
    }

    func setEditingComment(_ comment: PostComment, parentId: String?) {
        editingComment = (comment: comment, parentId: parentId)
        replyTarget = nil
        commentInput = comment.content
    }

    func cancelCommentInput() {
        replyTarget = nil
        editingComment = nil
        commentInput = ""
    }

    func submitComment() async {
        let trimmed = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let post else { return }
        guard !isCommentSubmitting else { return }

        isCommentSubmitting = true
        defer { isCommentSubmitting = false }

        do {
            if let editing = editingComment {
                let updated = try await client.updateComment(
                    postId: post.post_id,
                    commentId: editing.comment.comment_id,
                    content: trimmed
                )
                replaceComment(updated, parentId: editing.parentId)
            } else {
                let parentId = replyTarget?.comment_id
                if let parentId, !post.comments.contains(where: { $0.comment_id == parentId }) {
                    presentError("대댓글에는 답글을 작성할 수 없습니다.")
                    replyTarget = nil
                    return
                }
                let new = try await client.createComment(
                    postId: post.post_id,
                    parentCommentId: parentId,
                    content: trimmed
                )
                if let parentId {
                    appendReply(PostReply(
                        comment_id: new.comment_id,
                        content: new.content,
                        createdAt: new.createdAt,
                        creator: new.creator
                    ), to: parentId)
                } else {
                    appendComment(PostComment(
                        comment_id: new.comment_id,
                        content: new.content,
                        createdAt: new.createdAt,
                        creator: new.creator,
                        replies: []
                    ))
                }
            }
            commentInput = ""
            replyTarget = nil
            editingComment = nil
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func requestDeleteComment(commentId: String, parentId: String?) {
        pendingDeleteComment = (commentId: commentId, parentId: parentId)
        showDeleteCommentConfirm = true
    }

    func confirmDeleteComment() async {
        guard let pending = pendingDeleteComment, let post else { return }
        defer { pendingDeleteComment = nil }

        let snapshot = post.comments
        removeComment(commentId: pending.commentId, parentId: pending.parentId)

        do {
            try await client.deleteComment(postId: post.post_id, commentId: pending.commentId)
        } catch {
            presentError(error.localizedDescription)
            restoreComments(snapshot)
        }
    }

    func clearAlert() {
        alertMessage = nil
        showErrorAlert = false
    }

    // MARK: - Comments Mutation Helpers

    private func appendComment(_ comment: PostComment) {
        guard let current = post else { return }
        post = current.withComments(current.comments + [comment])
    }

    private func appendReply(_ reply: PostReply, to parentId: String) {
        guard let current = post else { return }
        let updated = current.comments.map { c in
            guard c.comment_id == parentId else { return c }
            return PostComment(
                comment_id: c.comment_id, content: c.content,
                createdAt: c.createdAt, creator: c.creator,
                replies: c.replies + [reply]
            )
        }
        post = current.withComments(updated)
    }

    private func replaceComment(_ newComment: PostComment, parentId: String?) {
        guard let current = post else { return }
        if let parentId {
            let updated = current.comments.map { c in
                guard c.comment_id == parentId else { return c }
                let updatedReplies = c.replies.map { r in
                    r.comment_id == newComment.comment_id
                        ? PostReply(comment_id: newComment.comment_id, content: newComment.content,
                                    createdAt: newComment.createdAt, creator: newComment.creator)
                        : r
                }
                return PostComment(comment_id: c.comment_id, content: c.content,
                                   createdAt: c.createdAt, creator: c.creator, replies: updatedReplies)
            }
            post = current.withComments(updated)
        } else {
            let updated = current.comments.map { c in
                c.comment_id == newComment.comment_id ? newComment : c
            }
            post = current.withComments(updated)
        }
    }

    private func removeComment(commentId: String, parentId: String?) {
        guard let current = post else { return }
        if let parentId {
            let updated = current.comments.map { c in
                guard c.comment_id == parentId else { return c }
                return PostComment(
                    comment_id: c.comment_id, content: c.content,
                    createdAt: c.createdAt, creator: c.creator,
                    replies: c.replies.filter { $0.comment_id != commentId }
                )
            }
            post = current.withComments(updated)
        } else {
            post = current.withComments(current.comments.filter { $0.comment_id != commentId })
        }
    }

    private func restoreComments(_ comments: [PostComment]) {
        guard let current = post else { return }
        post = current.withComments(comments)
    }

    private func presentError(_ message: String) {
        alertMessage = message
        showErrorAlert = true
    }

    // MARK: - Like State

    private func updatePostLikeState(isLiked: Bool, previousLiked: Bool? = nil) {
        guard let current = post else { return }
        let currentLiked = previousLiked ?? current.is_like
        let delta: Double = currentLiked == isLiked ? 0 : (isLiked ? 1 : -1)
        post = PostDetail(
            post_id: current.post_id, category: current.category, title: current.title,
            content: current.content, store: current.store, geolocation: current.geolocation,
            creator: current.creator, files: current.files,
            is_like: isLiked, like_count: max(0, current.like_count + delta),
            comments: current.comments, createdAt: current.createdAt, updatedAt: current.updatedAt
        )
    }
}

// MARK: - PostDetail helper

private extension PostDetail {
    func withComments(_ comments: [PostComment]) -> PostDetail {
        PostDetail(
            post_id: post_id, category: category, title: title,
            content: content, store: store, geolocation: geolocation,
            creator: creator, files: files,
            is_like: is_like, like_count: like_count,
            comments: comments, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}
