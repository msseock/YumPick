import SwiftUI

struct CommunityPostDetailView: View {
    let postId: String

    @State private var viewModel = CommunityPostDetailViewModel()
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
                ToolbarItem(placement: .topBarTrailing) {
                    ownerMenu
                }
            }
        }
        .alert("게시글을 삭제할까요?", isPresented: $viewModel.showDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task { await viewModel.deletePost() }
            }
            Button("취소", role: .cancel) {}
        }
        .onChange(of: viewModel.didDeletePost) { _, deleted in
            if deleted { dismiss() }
        }
        .task {
            await viewModel.loadDetail(postId: postId)
        }
    }

    private func postContent(_ post: PostDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 미디어 캐러셀
                if !post.files.isEmpty {
                    mediaCarousel(files: post.files)
                }

                VStack(alignment: .leading, spacing: 16) {
                    // 카테고리 + 제목
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.category)
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.actionAccent)
                        Text(post.title)
                            .font(YPFont.title1)
                            .foregroundStyle(YPColor.textPrimary)
                    }

                    // 작성자 + 날짜
                    HStack(spacing: 8) {
                        if let profilePath = post.creator.profileImage {
                            CachedImage(path: profilePath)
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(YPColor.backgroundSecondary)
                                .frame(width: 28, height: 28)
                        }
                        Text(post.creator.nick)
                            .font(YPFont.body3Bold)
                            .foregroundStyle(YPColor.textPrimary)
                        Spacer()
                        Text(DateFormatManager.shared.relativeDate(from: post.createdAt))
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                    }

                    Divider()

                    // 본문
                    Text(post.content)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 가게 정보
                    if let store = post.store, let name = store.name {
                        storeRow(store: store, name: name)
                    }

                    // 좋아요
                    likeRow(post: post)
                }
                .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                // 댓글
                commentsSection(comments: post.comments)
            }
        }
    }

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

    private func likeRow(post: PostDetail) -> some View {
        HStack(spacing: 6) {
            let isLiked = PostLikeStateStore.shared.isLiked(for: post.post_id, fallback: post.is_like)
            Button {
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
    }

    private func commentsSection(comments: [PostComment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("댓글 \(totalCommentCount(comments))개")
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
                    CommentRow(comment: comment)
                    Divider().padding(.horizontal, 16)
                }
            }
        }
    }

    private func totalCommentCount(_ comments: [PostComment]) -> Int {
        comments.reduce(0) { $0 + 1 + $1.replies.count }
    }

    private var ownerMenu: some View {
        Menu {
            NavigationLink(value: CommunityPath.compose(.edit(postId: postId))) {
                Label("수정", systemImage: "pencil")
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
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: PostComment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            commentItem(
                nick: comment.creator.nick,
                profilePath: comment.creator.profileImage,
                content: comment.content,
                createdAt: comment.createdAt,
                indent: false
            )

            ForEach(comment.replies) { reply in
                commentItem(
                    nick: reply.creator.nick,
                    profilePath: reply.creator.profileImage,
                    content: reply.content,
                    createdAt: reply.createdAt,
                    indent: true
                )
            }
        }
    }

    private func commentItem(
        nick: String,
        profilePath: String?,
        content: String,
        createdAt: String,
        indent: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if indent {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11))
                    .foregroundStyle(YPColor.textTertiary)
                    .padding(.top, 4)
            }

            if let path = profilePath {
                CachedImage(path: path)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(YPColor.backgroundSecondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(nick)
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YPColor.textPrimary)
                    Text(DateFormatManager.shared.relativeDate(from: createdAt))
                        .font(YPFont.caption2)
                        .foregroundStyle(YPColor.textTertiary)
                }
                Text(content)
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(indent ? YPColor.backgroundSecondary.opacity(0.5) : Color.clear)
    }
}
