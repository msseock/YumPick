import SwiftUI

struct CommunitySearchView: View {
    @State private var viewModel = CommunitySearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            resultList
        }
        .navigationTitle("검색")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isSearchFocused = true }
        .tapToHideKeyboard()
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(YPColor.textTertiary)
            TextField("게시글 제목 검색", text: $viewModel.query)
                .font(YPFont.body3)
                .focused($isSearchFocused)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.onQueryChanged(newValue)
                }
                .submitLabel(.search)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.onQueryChanged("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(YPColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(16)
    }

    @ViewBuilder
    private var resultList: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyQueryView
        } else if viewModel.results.isEmpty {
            noResultView
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.results) { post in
                        NavigationLink(value: CommunityPath.detail(postId: post.post_id)) {
                            SearchResultCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var emptyQueryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(YPColor.textTertiary)
            Text("게시글 제목을 검색해보세요.")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(YPColor.textTertiary)
            Text("'\(viewModel.query)'에 대한 결과가 없어요.")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SearchResultCard: View {
    let post: PostSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Text(post.creator.nick)
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)
        }
        .padding(14)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
