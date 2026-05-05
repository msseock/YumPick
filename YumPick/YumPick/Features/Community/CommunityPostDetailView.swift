import SwiftUI

struct CommunityPostDetailView: View {
    let postId: String

    @State private var viewModel = CommunityPostDetailViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let post = viewModel.post {
                postContent(post)
            } else if viewModel.errorMessage != nil {
                errorView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isOwner {
                ToolbarItem(placement: .topBarTrailing) { ownerMenu }
            }
        }
        .alert("게시글을 삭제할까요?", isPresented: $viewModel.showDeleteConfirm) {
            Button("삭제", role: .destructive) { Task { await viewModel.deletePost() } }
            Button("취소", role: .cancel) {}
        }
        .alert("댓글을 삭제할까요?", isPresented: $viewModel.showDeleteCommentConfirm) {
            Button("삭제", role: .destructive) { Task { await viewModel.confirmDeleteComment() } }
            Button("취소", role: .cancel) {}
        }
        .alert("요청에 실패했어요", isPresented: $viewModel.showErrorAlert) {
            Button("확인", role: .cancel) { viewModel.clearAlert() }
        } message: {
            Text(viewModel.alertMessage ?? "잠시 후 다시 시도해주세요.")
        }
        .onChange(of: viewModel.didDeletePost) { _, deleted in
            if deleted { dismiss() }
        }
        .task { await viewModel.loadDetail(postId: postId) }
    }

    // MARK: - Post Content

    private func postContent(_ post: PostDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !post.files.isEmpty { mediaCarousel(files: post.files) }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.category)
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.actionAccent)
                        Text(post.title)
                            .font(YPFont.title1)
                            .foregroundStyle(YPColor.textPrimary)
                    }

                    HStack(spacing: 8) {
                        profileImage(path: post.creator.profileImage)
                        NavigationLink(value: CommunityPath.userPosts(userId: post.creator.user_id)) {
                            Text(post.creator.nick)
                                .font(YPFont.body3Bold)
                                .foregroundStyle(YPColor.textPrimary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(DateFormatManager.shared.relativeDate(from: post.createdAt))
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                    }

                    Divider()

                    Text(post.content)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let store = post.store, let name = store.name {
                        storeRow(store: store, name: name)
                    }

                    likeRow(post: post)
                }
                .padding(16)

                Divider().padding(.horizontal, 16)
                commentsSection(comments: post.comments)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            commentInputBar
        }
        .onTapGesture { isInputFocused = false }
    }

    // MARK: - Media

    private func mediaCarousel(files: [String]) -> some View {
        TabView {
            ForEach(Array(files.enumerated()), id: \.offset) { _, path in
                CachedImage(path: path)
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
            }
        }
        .tabViewStyle(.page)
        .frame(height: 280)
    }

    // MARK: - Store Row

    private func storeRow(store: PostStore, name: String) -> some View {
        HStack(spacing: 10) {
            if let imagePath = store.store_image_urls?.first {
                CachedImage(path: imagePath)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textPrimary)
                if let category = store.category {
                    Text(category)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textTertiary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Like Row

    private func likeRow(post: PostDetail) -> some View {
        let isLiked = PostLikeStateStore.shared.isLiked(for: post.post_id, fallback: post.is_like)
        return Button {
            Task { await viewModel.toggleLike() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? YPColor.actionAccent : YPColor.textTertiary)
                Text("\(Int(viewModel.post?.like_count ?? post.like_count))")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comments Section

    private func commentsSection(comments: [PostComment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("댓글 \(comments.reduce(0) { $0 + 1 + $1.replies.count })개")
                .font(YPFont.body3Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if comments.isEmpty {
                Text("첫 댓글을 남겨보세요.")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        onReplyTapped: {
                            viewModel.setReplyTarget(comment)
                            isInputFocused = true
                        },
                        onEditCommentTapped: { viewModel.setEditingComment(comment, parentId: nil); isInputFocused = true },
                        onDeleteCommentTapped: { viewModel.requestDeleteComment(commentId: comment.comment_id, parentId: nil) },
                        onEditReplyTapped: { reply in viewModel.setEditingComment(
                            PostComment(comment_id: reply.comment_id, content: reply.content,
                                        createdAt: reply.createdAt, creator: reply.creator, replies: []),
                            parentId: comment.comment_id); isInputFocused = true },
                        onDeleteReplyTapped: { reply in
                            viewModel.requestDeleteComment(commentId: reply.comment_id, parentId: comment.comment_id)
                        },
                        isCommentOwner: viewModel.isCommentOwner
                    )
                    Divider().padding(.horizontal, 16)
                }
            }

            // 입력바 높이만큼 여백
            Color.clear.frame(height: 16)
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()

            // 답글 대상 / 수정 모드 표시
            if let target = viewModel.replyTarget {
                replyTargetBanner(nick: target.creator.nick)
            } else if let editing = viewModel.editingComment {
                editingBanner(content: editing.comment.content)
            }

            HStack(spacing: 10) {
                TextField(inputPlaceholder, text: $viewModel.commentInput, axis: .vertical)
                    .font(YPFont.body3)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(YPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)

                Button {
                    Task { await viewModel.submitComment() }
                } label: {
                    if viewModel.isCommentSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(
                                viewModel.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? YPColor.textTertiary : YPColor.actionAccent
                            )
                    }
                }
                .disabled(viewModel.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isCommentSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(YPColor.backgroundPrimary)
        }
    }

    private var inputPlaceholder: String {
        if viewModel.editingComment != nil { return "댓글 수정..." }
        if let target = viewModel.replyTarget { return "@\(target.creator.nick)에게 답글..." }
        return "댓글을 입력하세요"
    }

    private func replyTargetBanner(nick: String) -> some View {
        HStack {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12))
                .foregroundStyle(YPColor.textTertiary)
            Text("@\(nick)에게 답글")
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)
            Spacer()
            Button { viewModel.cancelCommentInput() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(YPColor.backgroundSecondary)
    }

    private func editingBanner(content: String) -> some View {
        HStack {
            Image(systemName: "pencil")
                .font(.system(size: 12))
                .foregroundStyle(YPColor.textTertiary)
            Text("댓글 수정 중")
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)
            Spacer()
            Button { viewModel.cancelCommentInput() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(YPColor.backgroundSecondary)
    }

    // MARK: - Owner Menu

    private var ownerMenu: some View {
        Menu {
            if let post = viewModel.post {
                NavigationLink(value: CommunityPath.compose(.edit(post))) {
                    Label("수정", systemImage: "pencil")
                }
            }
            Button(role: .destructive) {
                viewModel.showDeleteConfirm = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(YPColor.textPrimary)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 12) {
            Text("게시글을 불러올 수 없어요.")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
            Button("다시 시도") {
                Task { await viewModel.loadDetail(postId: postId) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func profileImage(path: String?) -> some View {
        Group {
            if let path {
                CachedImage(path: path)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(YPColor.backgroundSecondary)
                    .frame(width: 28, height: 28)
            }
        }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: PostComment
    let onReplyTapped: () -> Void
    let onEditCommentTapped: () -> Void
    let onDeleteCommentTapped: () -> Void
    let onEditReplyTapped: (PostReply) -> Void
    let onDeleteReplyTapped: (PostReply) -> Void
    let isCommentOwner: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            commentItem(
                id: comment.comment_id,
                nick: comment.creator.nick,
                creatorId: comment.creator.user_id,
                profilePath: comment.creator.profileImage,
                content: comment.content,
                createdAt: comment.createdAt,
                indent: false,
                onReply: onReplyTapped,
                onEdit: onEditCommentTapped,
                onDelete: onDeleteCommentTapped
            )

            ForEach(comment.replies) { reply in
                commentItem(
                    id: reply.comment_id,
                    nick: reply.creator.nick,
                    creatorId: reply.creator.user_id,
                    profilePath: reply.creator.profileImage,
                    content: reply.content,
                    createdAt: reply.createdAt,
                    indent: true,
                    onReply: nil,
                    onEdit: { onEditReplyTapped(reply) },
                    onDelete: { onDeleteReplyTapped(reply) }
                )
            }
        }
    }

    private func commentItem(
        id: String,
        nick: String,
        creatorId: String,
        profilePath: String?,
        content: String,
        createdAt: String,
        indent: Bool,
        onReply: (() -> Void)?,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if indent {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(YPColor.textTertiary)
                    .padding(.top, 4)
            }

            Group {
                if let path = profilePath {
                    CachedImage(path: path)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(YPColor.backgroundSecondary)
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(nick)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textPrimary)
                    Text(DateFormatManager.shared.relativeDate(from: createdAt))
                        .font(YPFont.caption2)
                        .foregroundStyle(YPColor.textTertiary)
                    Spacer()
                    if let onReply {
                        Button("답글") { onReply() }
                            .font(YPFont.caption2)
                            .foregroundStyle(YPColor.textTertiary)
                    }
                }
                Text(content)
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(indent ? YPColor.backgroundSecondary.opacity(0.5) : Color.clear)
        .contextMenu {
            if isCommentOwner(creatorId) {
                Button { onEdit() } label: { Label("수정", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("삭제", systemImage: "trash") }
            }
        }
    }
}
