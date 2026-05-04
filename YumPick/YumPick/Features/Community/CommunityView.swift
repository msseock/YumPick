import SwiftUI

struct CommunityView: View {
    @State private var viewModel = CommunityViewModel()
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
        .navigationTitle("커뮤니티")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: CommunityPath.search) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(YPColor.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: CommunityPath.compose(.create)) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(YPColor.textPrimary)
                }
            }
        }
        .task {
            await viewModel.fetchPosts(reset: true)
            armPagination()
        }
    }

    private var postList: some View {
        ScrollView {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                if viewModel.posts.isEmpty {
                    Text("게시글이 없어요.")
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(value: CommunityPath.detail(postId: post.post_id)) {
                                PostCard(post: post)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .refreshable {
            await reloadPosts()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryChip(title: "전체", isSelected: viewModel.selectedCategory == nil) {
                        viewModel.selectedCategory = nil
                        Task { await reloadPosts() }
                    }
                }
            }

            Spacer()

            Menu {
                ForEach(CommunityOrder.allCases, id: \.self) { order in
                    Button(order.label) {
                        viewModel.orderBy = order
                        Task { await reloadPosts() }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.orderBy.label)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(YPColor.textSecondary)
                }
            }
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

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(YPFont.caption1)
                .foregroundStyle(isSelected ? YPColor.actionAccent : YPColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? YPColor.actionAccent.opacity(0.1)
                        : YPColor.backgroundSecondary
                )
                .clipShape(Capsule())
        }
    }
}

private struct PostCard: View {
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

                if let imagePath = post.files.first {
                    CachedImage(path: imagePath)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 12) {
                Text(post.creator.nick)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)

                if let storeName = post.store?.name {
                    Text(storeName)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
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
        .shadow(
            color: Color(red: 123/255, green: 120/255, blue: 134/255).opacity(0.08),
            radius: 6, x: 0, y: 4
        )
    }
}
