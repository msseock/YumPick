import Foundation

enum CommunityOrder: String, CaseIterable {
    case latest = "createdAt"
    case popular = "likes"

    var label: String {
        switch self {
        case .latest:  return "최신순"
        case .popular: return "인기순"
        }
    }
}

@Observable
final class CommunityViewModel {
    var posts: [PostSummary] = []
    var isLoading = false
    var isPageLoading = false
    var errorMessage: String? = nil

    var selectedCategory: String? = nil
    var orderBy: CommunityOrder = .latest

    private(set) var nextCursor: String? = nil
    private(set) var hasMore = true
    private var loadedCursors: Set<String> = []

    var canLoadMore: Bool { hasMore && !isPageLoading }

    private let client: CommunityClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: CommunityClientProtocol = CommunityClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func fetchPosts(reset: Bool = true) async {
        guard reset || canLoadMore else { return }
        guard !isPageLoading else { return }

        let requestedCursor = reset ? nil : nextCursor
        if !reset {
            guard let requestedCursor else {
                hasMore = false
                return
            }
            guard !loadedCursors.contains(requestedCursor) else {
                hasMore = false
                nextCursor = nil
                return
            }
        }

        if reset {
            isLoading = true
            posts = []
            nextCursor = nil
            hasMore = true
            loadedCursors.removeAll()
        }

        isPageLoading = true
        defer {
            isPageLoading = false
            if reset { isLoading = false }
        }

        let geo = await locationManager.currentLocation() ?? Geolocation(longitude: 126.9780, latitude: 37.5665)
        do {
            let page = try await client.fetchGeolocationPosts(
                longitude: geo.longitude,
                latitude: geo.latitude,
                category: selectedCategory,
                orderBy: orderBy.rawValue,
                next: requestedCursor,
                limit: nil
            )

            if let requestedCursor {
                loadedCursors.insert(requestedCursor)
            }

            if reset {
                posts = page.posts
            } else {
                posts.append(contentsOf: page.posts)
            }

            if let cursor = page.nextCursor, !cursor.isEmpty, !loadedCursors.contains(cursor) {
                nextCursor = cursor
                hasMore = true
            } else {
                nextCursor = nil
                hasMore = false
            }
        } catch {
            errorMessage = error.localizedDescription
            hasMore = false
        }
    }

    func loadMore() async {
        await fetchPosts(reset: false)
    }
}
