import SwiftUI

struct CommunityView: View {
    @State private var viewModel = CommunityViewModel()
    @State private var bannerWebViewRoute: HomeBannerWebViewRoute?
    @State private var isPaginationArmed = false
    @State private var isPaginationTriggerVisible = false
    @State private var paginationTask: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                postList
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(YPColor.backgroundPrimary)
        .task {
            guard viewModel.posts.isEmpty else { return }
            await viewModel.fetchBannersIfNeeded()
            await viewModel.fetchPosts(reset: true)
            armPagination()
        }
        .sheet(item: $bannerWebViewRoute) { route in
            HomeBannerWebViewScreen(url: route.url)
        }
    }

    private var postList: some View {
        ScrollView {
            VStack(spacing: 0) {
                topActionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                timelineHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                YPBannerCarousel(banners: viewModel.banners) { banner in
                    bannerWebViewRoute = viewModel.webViewRoute(for: banner)
                }
                .padding(.bottom, 16)

                YPDivider()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                if viewModel.posts.isEmpty {
                    Text("게시글이 없어요.")
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(value: CommunityPath.detail(postId: post.post_id)) {
                                PostCard(
                                    post: post,
                                    isLiked: PostLikeStateStore.shared.isLiked(
                                        for: post.post_id,
                                        fallback: post.is_like
                                    ),
                                    onLikeTapped: {
                                        Task { await viewModel.toggleLike(postId: post.post_id) }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if viewModel.canLoadMore {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 1)
                                .onAppear {
                                    isPaginationTriggerVisible = true
                                    triggerPaginationIfNeeded()
                                }
                                .onDisappear {
                                    isPaginationTriggerVisible = false
                                }
                        }

                        if viewModel.isPageLoading && !viewModel.posts.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .refreshable {
            paginationTask?.cancel()
            paginationTask = nil
            isPaginationArmed = false
            await viewModel.fetchBannersIfNeeded()
            await viewModel.fetchPosts(reset: true)
            armPagination()
        }
    }

    private var topActionBar: some View {
        HStack(spacing: 10) {
            NavigationLink(value: CommunityPath.search) {
                HStack(spacing: 10) {
                    Image("Search")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(YPColor.brandBlackSprout)

                    Text("검색어를 입력해주세요.")
                        .font(YPFont.body2)
                        .foregroundStyle(YPColor.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(YPColor.backgroundPrimary)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(YPColor.brandBlackSprout, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)

            NavigationLink(value: CommunityPath.compose(.create)) {
                Image("Write")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(YPColor.backgroundPrimary)
                    .frame(width: 40, height: 40)
                    .background(YPColor.brandBlackSprout)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var timelineHeader: some View {
        HStack {
            Text("타임라인")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)

            Spacer()

            Button {
                viewModel.orderBy = viewModel.orderBy.next
                Task { await reloadPosts() }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.orderBy.label)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.brandBlackSprout)

                    Image("List")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(YPColor.brandBlackSprout)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func reloadPosts() async {
        paginationTask?.cancel()
        paginationTask = nil
        isPaginationArmed = false
        await viewModel.fetchPosts(reset: true)
        armPagination()
    }

    private func armPagination() {
        isPaginationArmed = true
        triggerPaginationIfNeeded()
    }

    private func triggerPaginationIfNeeded() {
        guard isPaginationArmed else { return }
        guard isPaginationTriggerVisible else { return }
        guard viewModel.canLoadMore else { return }
        guard paginationTask == nil else { return }

        isPaginationArmed = false
        paginationTask = Task {
            await viewModel.loadMore()
            await MainActor.run {
                paginationTask = nil
                armPagination()
            }
        }
    }
}

// MARK: - Subviews

private struct PostCard: View {
    let post: PostSummary
    let isLiked: Bool
    let onLikeTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            authorRow

            if !post.files.isEmpty {
                mediaGrid
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(post.title)
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(YPColor.actionAccent)

                    Text("\(Int(post.like_count))개")
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YPColor.textPrimary)
                }
                .lineLimit(1)
            }

            Text(post.content)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textTertiary)
                .lineLimit(3)

            storeBanner
        }
        .padding(.bottom, 14)
        .background(YPColor.backgroundPrimary)
    }

    private var authorRow: some View {
        HStack(spacing: 8) {
            CachedImage(path: post.creator.profileImage)
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(post.creator.nick)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(1)

                Text(DateFormatManager.shared.relativeDate(from: post.createdAt))
                    .font(YPFont.caption2)
                    .foregroundStyle(YPColor.textTertiary)
            }

            Spacer()
        }
    }

    private var mediaGrid: some View {
        ZStack(alignment: .topLeading) {
            CommunityPostMediaGrid(paths: post.files)

            Button(action: onLikeTapped) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isLiked ? YPColor.actionAccent : YPColor.backgroundPrimary)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var storeBanner: some View {
        if let store = post.store, let storeName = store.name, !storeName.isEmpty {
            HStack(spacing: 10) {
                CachedImage(path: store.store_image_urls?.first)
                    .frame(width: 58, height: 58)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(storeName)
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YPColor.brandBlackSprout)
                        .lineLimit(1)

                    Text(storeSubtitle(for: store))
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.brandDeepSprout)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(height: 58)
            .background(YPColor.backgroundBrandSubtle.opacity(0.75))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(YPColor.brandBlackSprout.opacity(0.45), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func storeSubtitle(for store: PostStore) -> String {
        [store.category, store.hashTags?.prefix(2).joined(separator: " ")]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private struct CommunityPostMediaGrid: View {
    let paths: [String]

    private let spacing: CGFloat = 4

    @ViewBuilder
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            if paths.count == 1, let path = paths.first {
                mediaTile(path: path, width: width, height: height)
            } else if paths.count == 2 {
                let tileWidth = (width - spacing) / 2

                HStack(spacing: spacing) {
                    mediaTile(path: paths[0], width: tileWidth, height: height)
                    mediaTile(path: paths[1], width: tileWidth, height: height)
                }
                .frame(width: width, height: height)
                .clipped()
            } else if paths.count == 3 {
                let sideWidth = (width - spacing) * 0.36
                let mainWidth = width - sideWidth - spacing
                let sideHeight = (height - spacing) / 2

                HStack(spacing: spacing) {
                    mediaTile(path: paths[0], width: mainWidth, height: height)

                    VStack(spacing: spacing) {
                        mediaTile(path: paths[1], width: sideWidth, height: sideHeight)
                        mediaTile(path: paths[2], width: sideWidth, height: sideHeight)
                    }
                    .frame(width: sideWidth, height: height)
                    .clipped()
                }
                .frame(width: width, height: height)
                .clipped()
            } else if paths.count >= 4 {
                let tileWidth = (width - spacing) / 2
                let tileHeight = (height - spacing) / 2

                VStack(spacing: spacing) {
                    HStack(spacing: spacing) {
                        mediaTile(path: paths[0], width: tileWidth, height: tileHeight)
                        mediaTile(path: paths[1], width: tileWidth, height: tileHeight)
                    }

                    HStack(spacing: spacing) {
                        mediaTile(path: paths[2], width: tileWidth, height: tileHeight)
                        overflowTile(path: paths[3], extraCount: paths.count - 4, width: tileWidth, height: tileHeight)
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .clipped()
    }

    private func mediaTile(path: String, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if isVideoPath(path) {
                VideoThumbnailView(path: path)
            } else {
                CachedImage(path: path)
            }
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .clipped()
    }

    private func overflowTile(path: String, extraCount: Int, width: CGFloat, height: CGFloat) -> some View {
        mediaTile(path: path, width: width, height: height)
            .overlay {
                if extraCount > 0 {
                    Color.black.opacity(0.35)
                    Text("+\(extraCount)")
                        .font(YPFont.body1Bold)
                        .foregroundStyle(YPColor.backgroundPrimary)
                }
            }
    }
}
