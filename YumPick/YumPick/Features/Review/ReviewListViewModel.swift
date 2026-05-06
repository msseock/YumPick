import Foundation

@Observable
final class ReviewListViewModel {
    var reviews: [Review] = []
    var ratings: [ReviewRating] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String? = nil
    var selectedOrderBy = "latest"

    private var nextCursor: String = ""
    private var hasMore = true

    let storeId: String
    private let client: ReviewClientProtocol

    init(storeId: String, client: ReviewClientProtocol = ReviewClient()) {
        self.storeId = storeId
        self.client = client
    }

    var totalCount: Int { ratings.reduce(0) { $0 + $1.count } }

    var averageRating: Double {
        guard totalCount > 0 else { return 0 }
        let sum = ratings.reduce(0) { $0 + $1.rating * $1.count }
        return Double(sum) / Double(totalCount)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let reviewsTask = client.fetchReviews(storeId: storeId, next: nil, limit: 10, orderBy: selectedOrderBy)
            async let ratingsTask = client.fetchRatings(storeId: storeId)
            let (page, fetchedRatings) = try await (reviewsTask, ratingsTask)
            reviews = page.reviews
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != "0"
            ratings = fetchedRatings
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.fetchReviews(
                storeId: storeId, next: nextCursor, limit: 10, orderBy: selectedOrderBy
            )
            reviews.append(contentsOf: page.reviews)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != "0"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeOrder(_ orderBy: String) async {
        guard orderBy != selectedOrderBy else { return }
        selectedOrderBy = orderBy
        nextCursor = ""
        hasMore = true
        reviews = []
        await load()
    }
}
