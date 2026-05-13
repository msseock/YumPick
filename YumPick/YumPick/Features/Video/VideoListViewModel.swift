import Foundation

@MainActor
@Observable
final class VideoListViewModel {
    var videos: [Video] = []
    var isLoading: Bool = false
    var isPageLoading: Bool = false
    var errorMessage: String? = nil

    private var nextCursor: String? = nil
    private var hasMore: Bool = true
    private var hasLoaded: Bool = false
    private let client: VideoClientProtocol

    init(client: VideoClientProtocol = FixtureClientFactory.videoClient()) {
        self.client = client
    }

    var canLoadMore: Bool {
        hasMore && !isPageLoading
    }

    var isEmpty: Bool {
        !isLoading && videos.isEmpty && errorMessage == nil
    }

    func onAppear() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await client.fetchVideos(next: nil, limit: nil)
            videos = page.videos
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem: Video) async {
        guard let lastId = videos.last?.video_id, lastId == currentItem.video_id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isPageLoading, !isLoading else { return }
        guard let cursor = nextCursor else {
            hasMore = false
            return
        }
        isPageLoading = true
        defer { isPageLoading = false }
        do {
            let page = try await client.fetchVideos(next: cursor, limit: nil)
            videos.append(contentsOf: page.videos)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
            hasMore = false
        }
    }
}
