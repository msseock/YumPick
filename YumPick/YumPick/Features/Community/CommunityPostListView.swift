import SwiftUI

struct CommunityPostListView: View {
    let title: String
    let mode: PostListMode

    @State private var viewModel: CommunityPostListViewModel
    @State private var isPaginationArmed = false
    @State private var isPaginationTriggerVisible = false
    @State private var paginationTask: Task<Void, Never>? = nil

    init(title: String, mode: PostListMode) {
        self.title = title
        self.mode = mode
        self._viewModel = State(initialValue: CommunityPostListViewModel(mode: mode))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.posts.isEmpty {
                emptyView
            } else {
                postList
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchPosts(reset: true)
            armPagination()
        }
        .refreshable {
            paginationTask?.cancel()
            paginationTask = nil
            isPaginationArmed = false
            await viewModel.fetchPosts(reset: true)
            armPagination()
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: CommunityPath.detail(postId: post.post_id)) {
                        PostListCard(post: post)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.canLoadMore {
                    Color.clear
                        .frame(maxWidth: .infinity).frame(height: 1)
                        .onAppear {
                            isPaginationTriggerVisible = true
                            triggerPaginationIfNeeded()
                        }
                        .onDisappear { isPaginationTriggerVisible = false }
                }

                if viewModel.isPageLoading && !viewModel.posts.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 18)
                }
            }
            .padding(16)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(YPColor.textTertiary)
            Text("게시글이 없어요.")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func armPagination() {
        isPaginationArmed = true
        triggerPaginationIfNeeded()
    }

    private func triggerPaginationIfNeeded() {
        guard isPaginationArmed, isPaginationTriggerVisible,
              viewModel.canLoadMore, paginationTask == nil else { return }
        isPaginationArmed = false
        paginationTask = Task {
            await viewModel.loadMore()
            await MainActor.run { paginationTask = nil; armPagination() }
        }
    }
}

private struct PostListCard: View {
    let post: PostSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.category)
                        .font(YPFont.caption2)
                        .foregroundStyle(YPColor.actionAccent)
                    Text(post.title)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YPColor.textPrimary)
                        .lineLimit(1)
                    Text(post.content)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if let path = post.files.first {
                    ZStack {
                        CachedImage(path: path)
                        if isVideoPath(path) { VideoThumbnailOverlay() }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 12) {
                Text(post.creator.nick)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                Text(DateFormatManager.shared.relativeDate(from: post.createdAt))
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(YPColor.actionAccent)
                    Text("\(Int(post.like_count))")
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textTertiary)
                }
            }
        }
        .padding(16)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
    }
}
