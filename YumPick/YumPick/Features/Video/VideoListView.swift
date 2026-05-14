import SwiftUI

struct VideoListView: View {
    @State private var viewModel = VideoListViewModel()
    @State private var selectedVideo: Video?

    private let shortGridColumns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        content
            .navigationBarHidden(true)
            .task { await viewModel.onAppear() }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoDetailView(
                    video: video,
                    relatedVideos: viewModel.videos.filter { $0.video_id != video.video_id }
                ) {
                    selectedVideo = nil
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.videos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(YP2Color.paper)
        } else if let message = viewModel.errorMessage, viewModel.videos.isEmpty {
            errorState(message: message)
        } else if viewModel.isEmpty {
            emptyState
        } else {
            list
        }
    }

    // MARK: - List

    private var sortedVideos: [Video] {
        viewModel.videos.sorted(by: { $0.view_count > $1.view_count })
    }

    private var heroVideo: Video? { sortedVideos.first }
    private var shortVideos: [Video] { Array(sortedVideos.dropFirst()) }

    private var list: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    pageHeader
                    heroSection
                    shortsSection
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
            .background(YP2Color.paper)
            .refreshable { await viewModel.refresh() }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("YUMPICK PLAY")
                .font(.custom("Pretendard-Bold", size: 12))
                .foregroundStyle(YP2Color.textMuted)

            Text("먹는 장면으로\n고르는 한 끼")
                .font(.custom("Pretendard-Bold", size: 30))
                .foregroundStyle(YP2Color.ink)
                .lineSpacing(-2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YP2Color.paper)
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        if let hero = heroVideo {
            YP2VideoHeroCard(video: hero) {
                selectedVideo = hero
            }
        }
    }

    // MARK: - Shorts

    private var shortsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("인기 숏폼")
                    .font(.custom("Pretendard-Bold", size: 22))
                    .foregroundStyle(YP2Color.ink)

                Spacer()

                Text("전체")
                    .font(.custom("Pretendard-Bold", size: 12))
                    .foregroundStyle(YP2Color.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: shortGridColumns, spacing: 10) {
                ForEach(shortVideos) { video in
                    shortCard(video)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isPageLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 18)
            }

            Color.clear.frame(height: 100)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YP2Color.paper)
    }

    private func shortCard(_ video: Video) -> some View {
        YP2VideoShortCard(video: video) {
            selectedVideo = video
        }
        .task {
            await viewModel.loadMoreIfNeeded(currentItem: video)
        }
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(YP2Color.textTertiary)
            Text("표시할 비디오가 없습니다")
                .font(.custom("Pretendard-Medium", size: 14))
                .foregroundStyle(YP2Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YP2Color.paper)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(YP2Color.order)
            Text(message)
                .font(.custom("Pretendard-Medium", size: 14))
                .foregroundStyle(YP2Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("다시 시도")
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.ink)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(YP2Color.order)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YP2Color.paper)
    }
}
