import SwiftUI

struct VideoListView: View {
    @State private var viewModel = VideoListViewModel()
    @State private var selectedVideo: Video? = nil

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("비디오")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedVideo) { video in
                    VideoDetailView(video: video)
                }
        }
        .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.videos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(YPColor.backgroundPrimary)
        } else if let message = viewModel.errorMessage, viewModel.videos.isEmpty {
            errorState(message: message)
        } else if viewModel.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(viewModel.videos) { video in
                Button {
                    selectedVideo = video
                } label: {
                    VideoListCell(video: video)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(YPColor.backgroundPrimary)
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: video)
                }
            }

            if viewModel.isPageLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(YPColor.backgroundPrimary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(YPColor.backgroundPrimary)
        .refreshable { await viewModel.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(YPColor.textTertiary)
            Text("표시할 비디오가 없습니다")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YPColor.backgroundPrimary)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(YPColor.actionAccent)
            Text(message)
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("다시 시도") {
                Task { await viewModel.refresh() }
            }
            .font(YPFont.body2Bold)
            .foregroundStyle(YPColor.actionPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YPColor.backgroundPrimary)
    }
}

