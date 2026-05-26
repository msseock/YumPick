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
        .background(YP2Color.backgroundPrimary)
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
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                searchBarView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                YPBannerCarousel(banners: viewModel.banners) { banner in
                    bannerWebViewRoute = viewModel.webViewRoute(for: banner)
                }
                .padding(.bottom, 16)

                if viewModel.posts.isEmpty {
                    Text("게시글이 없어요.")
                        .font(YPFont.body3)
                        .foregroundStyle(YP2Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    trendCard
                        .padding(.bottom, 16)

                    LazyVStack(spacing: 16) {
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
                            .padding(.horizontal, 20)

                            if post.post_id == viewModel.posts.first?.post_id {
                                miniPromoCard
                            }
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

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LOCAL PICK")
                    .font(.custom("Pretendard-Bold", size: 12))
                    .foregroundStyle(YP2Color.textMuted)

                Text("동네 음식 후기")
                    .font(.custom("Pretendard-Bold", size: 30))
                    .foregroundStyle(YP2Color.textPrimary)
            }

            Spacer()

            NavigationLink(value: CommunityPath.compose(.create)) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(YP2Color.ink)
                    .frame(width: 46, height: 46)
                    .background(YP2Color.order)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBarView: some View {
        NavigationLink(value: CommunityPath.search) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(YP2Color.textMuted)

                Text("가게, 메뉴, 후기 검색")
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.textMuted)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(YP2Color.fog)
        }
        .buttonStyle(.plain)
    }

    private var sortRow: some View {
        HStack {
            Text("타임라인")
                .font(YPFont.body1Bold)
                .foregroundStyle(YP2Color.textPrimary)

            Spacer()

            Button {
                viewModel.orderBy = viewModel.orderBy.next
                Task { await reloadPosts() }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.orderBy.label)
                        .font(YPFont.body3)
                        .foregroundStyle(YP2Color.textMuted)

                    Image("List")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(YP2Color.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trendCard: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let firstFile = viewModel.posts.first?.files.first {
                    CachedImage(path: firstFile)
                } else {
                    Rectangle().fill(YP2Color.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .clipped()

            Color.black.opacity(0.65)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                Text("HOT")
                    .font(.custom("Pretendard-Bold", size: 11))
                    .foregroundStyle(YP2Color.ink)
                    .frame(width: 70, height: 26)
                    .background(YP2Color.order)
                    .padding(.leading, 16)

                Text("방금 올라온 픽업 후기 \(viewModel.posts.count)개")
                    .font(.custom("Pretendard-Bold", size: 19))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 104)
        .clipShape(Rectangle())
        .padding(.horizontal, 20)
    }

    private var miniPromoCard: some View {
        HStack(spacing: 12) {
            Image("Order_Empty")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(YP2Color.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("이번 주 리뷰 챌린지")
                    .font(.custom("Pretendard-Bold", size: 15))
                    .foregroundStyle(YP2Color.textPrimary)

                Text("후기 작성하고 2,000P 받기")
                    .font(.custom("Pretendard-Bold", size: 12))
                    .foregroundStyle(YP2Color.textMuted)
            }

            Spacer()
        }
        .padding(14)
        .background(YP2Color.fog)
        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 12) {
            ptop

            Text(post.title)
                .font(YPFont.body1Bold)
                .foregroundStyle(YP2Color.textPrimary)
                .lineLimit(2)

            Text(post.content)
                .font(YPFont.body2)
                .foregroundStyle(YP2Color.textPrimary)
                .lineLimit(3)
                .lineSpacing(14 * 0.35)

            if !post.files.isEmpty {
                CommunityPostMediaGrid(paths: post.files)
            }
        }
        .padding(14)
        .background(YP2Color.backgroundPrimary)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private var ptop: some View {
        HStack(alignment: .top, spacing: 10) {
            CachedImage(path: post.creator.profileImage)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(post.creator.nick)
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(1)

                Text(metaText)
                    .font(.custom("Pretendard-Medium", size: 11))
                    .foregroundStyle(YP2Color.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onLikeTapped) {
                HStack(spacing: 4) {
                    Image(isLiked ? "Like_Fill" : "Like_Empty")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(YP2Color.ink)

                    Text("\(Int(post.like_count))")
                        .font(.custom("Pretendard-Bold", size: 12))
                        .foregroundStyle(YP2Color.ink)
                }
                .frame(width: 48, height: 26)
                .background(isLiked ? YP2Color.order : YP2Color.fog)
                .clipShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var metaText: String {
        let date = DateFormatManager.shared.relativeDate(from: post.createdAt)
        if let store = post.store, let name = store.name, !name.isEmpty {
            return "\(date) · \(name)"
        }
        return date
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
        .frame(height: 150)
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
                        .foregroundStyle(YP2Color.backgroundPrimary)
                }
            }
    }
}
