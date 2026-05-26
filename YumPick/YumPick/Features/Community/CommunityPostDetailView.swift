import SwiftUI

struct CommunityPostDetailView: View {
    let postId: String
    var onOpenChatRoom: ((String) -> Void)?

    @State private var viewModel = CommunityPostDetailViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    @Namespace private var mediaNamespace
    @State private var selectedMediaIndex: Int? = nil

    private var isLightboxActive: Bool { selectedMediaIndex != nil }

    var body: some View {
        ZStack {
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

            if let post = viewModel.post, isLightboxActive {
                MediaLightboxView(
                    files: post.files,
                    selectedIndex: $selectedMediaIndex,
                    namespace: mediaNamespace
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isLightboxActive ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(YP2Color.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if viewModel.isOwner && !isLightboxActive {
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
        .onChange(of: viewModel.chatRoomToOpen) { _, roomID in
            guard let roomID else { return }
            onOpenChatRoom?(roomID)
            viewModel.chatRoomToOpen = nil
        }
        .background(YP2Color.backgroundPrimary)
        .task { await viewModel.loadDetail(postId: postId) }
    }

    // MARK: - Post Content

    private func postContent(_ post: PostDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !post.files.isEmpty { mediaCarousel(files: post.files) }

                articleSection(post)

                Rectangle()
                    .fill(YP2Color.backgroundSecondary)
                    .frame(height: 10)

                commentsSection(comments: post.comments)
            }
        }
        .background(YP2Color.backgroundPrimary)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isLightboxActive { commentInputBar }
        }
        .onTapGesture { isInputFocused = false }
    }

    private func articleSection(_ post: PostDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(post.category)
                    .font(.custom("Pretendard-Bold", size: 11))
                    .foregroundStyle(YP2Color.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(YP2Color.order)

                Text(post.title)
                    .font(.custom("Pretendard-Bold", size: 24))
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(nil)
                    .lineSpacing(4)
            }

            authorRow(post: post)

            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)

            Text(post.content)
                .font(.custom("Pretendard-Medium", size: 15))
                .foregroundStyle(YP2Color.textPrimary)
                .lineSpacing(7)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let store = post.store, let name = store.name {
                storeRow(store: store, name: name)
            }

            likeRow(post: post)
        }
        .padding(.horizontal, 20)
        .padding(.top, post.files.isEmpty ? 22 : 20)
        .padding(.bottom, 24)
        .background(YP2Color.backgroundPrimary)
    }

    private func authorRow(post: PostDetail) -> some View {
        HStack(alignment: .center, spacing: 10) {
            profileImage(path: post.creator.profileImage)

            VStack(alignment: .leading, spacing: 3) {
                NavigationLink(value: CommunityPath.userPosts(userId: post.creator.user_id)) {
                    Text(post.creator.nick)
                        .font(.custom("Pretendard-Bold", size: 14))
                        .foregroundStyle(YP2Color.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Text(DateFormatManager.shared.relativeDate(from: post.createdAt))
                    .font(.custom("Pretendard-Medium", size: 11))
                    .foregroundStyle(YP2Color.textMuted)
            }

            Spacer()

            if !viewModel.isOwner {
                Button {
                    Task { await viewModel.startChat(opponentUserID: post.creator.user_id) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("채팅")
                            .font(.custom("Pretendard-Bold", size: 12))
                    }
                    .foregroundStyle(YP2Color.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(YP2Color.fog)
                    .overlay {
                        Rectangle()
                            .stroke(YP2Color.borderDefault, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Media

    private func mediaCarousel(files: [String]) -> some View {
        TabView {
            ForEach(Array(files.enumerated()), id: \.offset) { idx, path in
                Group {
                    if isVideoPath(path) {
                        VideoThumbnailView(path: path)
                            .matchedGeometryEffect(id: path, in: mediaNamespace)
                    } else {
                        CachedImage(path: path)
                            .scaledToFill()
                            .clipped()
                            .matchedGeometryEffect(id: path, in: mediaNamespace)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedMediaIndex = idx
                    }
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 320)
    }

    // MARK: - Store Row

    private func storeRow(store: PostStore, name: String) -> some View {
        HStack(spacing: 12) {
            if let imagePath = store.store_image_urls?.first {
                CachedImage(path: imagePath)
                    .frame(width: 52, height: 52)
                    .clipped()
            } else {
                Rectangle()
                    .fill(YP2Color.fog)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image("Order_Empty")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(YP2Color.textTertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("방문한 가게")
                    .font(.custom("Pretendard-Bold", size: 11))
                    .foregroundStyle(YP2Color.textMuted)
                Text(name)
                    .font(.custom("Pretendard-Bold", size: 15))
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(1)
                if let category = store.category {
                    Text(category)
                        .font(.custom("Pretendard-Medium", size: 12))
                        .foregroundStyle(YP2Color.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(YP2Color.backgroundSecondary)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    // MARK: - Like Row

    private func likeRow(post: PostDetail) -> some View {
        let isLiked = PostLikeStateStore.shared.isLiked(for: post.post_id, fallback: post.is_like)
        return Button {
            Task { await viewModel.toggleLike() }
        } label: {
            HStack(spacing: 6) {
                Image(isLiked ? "Like_Fill" : "Like_Empty")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(isLiked ? YP2Color.order : YP2Color.ink)
                Text("\(Int(viewModel.post?.like_count ?? post.like_count))")
                    .font(.custom("Pretendard-Bold", size: 13))
            }
            .foregroundStyle(isLiked ? YP2Color.order : YP2Color.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(isLiked ? YP2Color.ink : YP2Color.fog)
            .overlay {
                Rectangle()
                    .stroke(isLiked ? YP2Color.ink : YP2Color.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comments Section

    private func commentsSection(comments: [PostComment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("댓글")
                    .font(.custom("Pretendard-Bold", size: 18))
                    .foregroundStyle(YP2Color.textPrimary)
                Text("\(comments.reduce(0) { $0 + 1 + $1.replies.count })")
                    .font(.custom("Pretendard-Bold", size: 13))
                    .foregroundStyle(YP2Color.ink)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(YP2Color.order)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if comments.isEmpty {
                Text("첫 댓글을 남겨보세요.")
                    .font(.custom("Pretendard-Medium", size: 14))
                    .foregroundStyle(YP2Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 34)
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
                    Rectangle()
                        .fill(YP2Color.borderDefault)
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
            }

            // 입력바 높이만큼 여백
            Color.clear.frame(height: 16)
        }
        .background(YP2Color.backgroundPrimary)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)

            // 답글 대상 / 수정 모드 표시
            if let target = viewModel.replyTarget {
                replyTargetBanner(nick: target.creator.nick)
            } else if let editing = viewModel.editingComment {
                editingBanner(content: editing.comment.content)
            }

            HStack(spacing: 10) {
                TextField(inputPlaceholder, text: $viewModel.commentInput, axis: .vertical)
                    .font(.custom("Pretendard-Medium", size: 14))
                    .foregroundStyle(YP2Color.textPrimary)
                    .tint(YP2Color.ink)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(YP2Color.backgroundSecondary)
                    .overlay {
                        Rectangle()
                            .stroke(YP2Color.borderDefault, lineWidth: 1)
                    }
                    .focused($isInputFocused)

                Button {
                    Task { await viewModel.submitComment() }
                } label: {
                    if viewModel.isCommentSubmitting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                viewModel.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? YP2Color.textTertiary : YP2Color.ink
                            )
                            .frame(width: 42, height: 42)
                            .background(
                                viewModel.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? YP2Color.fog : YP2Color.order
                            )
                            .overlay {
                                Rectangle()
                                    .stroke(YP2Color.borderDefault, lineWidth: 1)
                            }
                    }
                }
                .disabled(viewModel.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isCommentSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(YP2Color.backgroundPrimary)
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
                .foregroundStyle(YP2Color.textMuted)
            Text("@\(nick)에게 답글")
                .font(.custom("Pretendard-Medium", size: 12))
                .foregroundStyle(YP2Color.textMuted)
            Spacer()
            Button { viewModel.cancelCommentInput() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(YP2Color.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(YP2Color.backgroundSecondary)
    }

    private func editingBanner(content: String) -> some View {
        HStack {
            Image(systemName: "pencil")
                .font(.system(size: 12))
                .foregroundStyle(YP2Color.textMuted)
            Text("댓글 수정 중")
                .font(.custom("Pretendard-Medium", size: 12))
                .foregroundStyle(YP2Color.textMuted)
            Spacer()
            Button { viewModel.cancelCommentInput() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(YP2Color.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(YP2Color.backgroundSecondary)
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
                .foregroundStyle(YP2Color.textPrimary)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 12) {
            Text("게시글을 불러올 수 없어요.")
                .font(.custom("Pretendard-Bold", size: 16))
                .foregroundStyle(YP2Color.textPrimary)
            Button("다시 시도") {
                Task { await viewModel.loadDetail(postId: postId) }
            }
            .font(.custom("Pretendard-Bold", size: 13))
            .foregroundStyle(YP2Color.ink)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(YP2Color.order)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YP2Color.backgroundPrimary)
    }

    // MARK: - Helpers

    private func profileImage(path: String?) -> some View {
        Group {
            if let path {
                CachedImage(path: path)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(YP2Color.backgroundSecondary)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(YP2Color.textTertiary)
                    }
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
                    .foregroundStyle(YP2Color.textTertiary)
                    .padding(.top, 5)
            }

            Group {
                if let path = profilePath {
                    CachedImage(path: path)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(YP2Color.backgroundSecondary)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(YP2Color.textTertiary)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(nick)
                        .font(.custom("Pretendard-Bold", size: 13))
                        .foregroundStyle(YP2Color.textPrimary)
                    Text(DateFormatManager.shared.relativeDate(from: createdAt))
                        .font(.custom("Pretendard-Medium", size: 11))
                        .foregroundStyle(YP2Color.textMuted)
                    Spacer()
                    if let onReply {
                        Button("답글") { onReply() }
                            .font(.custom("Pretendard-Bold", size: 11))
                            .foregroundStyle(YP2Color.textMuted)
                    }
                    
                    if isCommentOwner(creatorId) {
                        Menu {
                            Button { onEdit() } label: { Label("수정", systemImage: "pencil") }
                            Button(role: .destructive) { onDelete() } label: { Label("삭제", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(YP2Color.textMuted)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                    }
                }
                Text(content)
                    .font(.custom("Pretendard-Medium", size: 14))
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(indent ? YP2Color.backgroundSecondary : YP2Color.backgroundPrimary)
        .contextMenu {
            if isCommentOwner(creatorId) {
                Button { onEdit() } label: { Label("수정", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("삭제", systemImage: "trash") }
            }
        }
    }
}
