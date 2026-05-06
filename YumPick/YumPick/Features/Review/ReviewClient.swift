import Foundation

// MARK: - Protocol

protocol ReviewClientProtocol {
    func uploadFiles(storeId: String, parts: [MultipartData]) async throws -> [String]
    func createReview(storeId: String, request: CreateReviewRequest) async throws -> ReviewDetail
    func fetchReviews(storeId: String, next: String?, limit: Int?, orderBy: String?) async throws -> ReviewPage
    func fetchReview(storeId: String, reviewId: String) async throws -> ReviewDetail
    func updateReview(storeId: String, reviewId: String, request: UpdateReviewRequest) async throws -> ReviewDetail
    func deleteReview(storeId: String, reviewId: String) async throws
    func fetchRatings(storeId: String) async throws -> [ReviewRating]
}

// MARK: - Request DTOs

struct CreateReviewRequest: Encodable {
    let content: String
    let rating: Int
    let review_image_urls: [String]
    let order_code: String
}

struct UpdateReviewRequest: Encodable {
    let content: String?
    let rating: Int?
    let review_image_urls: [String]?
}

struct ReviewPage {
    let reviews: [Review]
    let nextCursor: String
}

// MARK: - Endpoints

private enum ReviewEndpoint: Endpoint {
    case uploadFiles(storeId: String, parts: [MultipartData])
    case createReview(storeId: String, body: CreateReviewRequest)
    case fetchReviews(storeId: String, next: String?, limit: Int?, orderBy: String?)
    case fetchReview(storeId: String, reviewId: String)
    case updateReview(storeId: String, reviewId: String, body: UpdateReviewRequest)
    case deleteReview(storeId: String, reviewId: String)
    case fetchRatings(storeId: String)

    var path: String {
        switch self {
        case .uploadFiles(let storeId, _):              return "/v1/stores/\(storeId)/reviews/files"
        case .createReview(let storeId, _):             return "/v1/stores/\(storeId)/reviews"
        case .fetchReviews(let storeId, _, _, _):       return "/v1/stores/\(storeId)/reviews"
        case .fetchReview(let storeId, let reviewId):   return "/v1/stores/\(storeId)/reviews/\(reviewId)"
        case .updateReview(let storeId, let reviewId, _): return "/v1/stores/\(storeId)/reviews/\(reviewId)"
        case .deleteReview(let storeId, let reviewId):  return "/v1/stores/\(storeId)/reviews/\(reviewId)"
        case .fetchRatings(let storeId):                return "/v1/stores/\(storeId)/reviews/reviews-ratings"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .uploadFiles:   return .post
        case .createReview:  return .post
        case .fetchReviews:  return .get
        case .fetchReview:   return .get
        case .updateReview:  return .put
        case .deleteReview:  return .delete
        case .fetchRatings:  return .get
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .uploadFiles(_, let parts):
            return .multipart(parts)
        case .createReview(_, let body):
            return .body(body)
        case .fetchReviews(_, let next, let limit, let orderBy):
            var q: [String: String] = [:]
            if let next, !next.isEmpty { q["next"] = next }
            if let limit { q["limit"] = "\(limit)" }
            if let orderBy { q["order_by"] = orderBy }
            return q.isEmpty ? .none : .query(q)
        case .updateReview(_, _, let body):
            return .body(body)
        case .fetchReview, .deleteReview, .fetchRatings:
            return .none
        }
    }
}

// MARK: - Response Wrappers

private struct ReviewListResponse: Decodable {
    let data: [Review]
    let next_cursor: String
}

private struct ReviewImageResponse: Decodable {
    let review_image_urls: [String]
}

private struct ReviewRatingListResponse: Decodable {
    let data: [ReviewRating]
}

// MARK: - Real Implementation

final class ReviewClient: ReviewClientProtocol {
    func uploadFiles(storeId: String, parts: [MultipartData]) async throws -> [String] {
        let response: ReviewImageResponse = try await NetworkManager.shared.request(
            ReviewEndpoint.uploadFiles(storeId: storeId, parts: parts)
        )
        return response.review_image_urls
    }

    func createReview(storeId: String, request: CreateReviewRequest) async throws -> ReviewDetail {
        try await NetworkManager.shared.request(
            ReviewEndpoint.createReview(storeId: storeId, body: request)
        )
    }

    func fetchReviews(storeId: String, next: String?, limit: Int?, orderBy: String?) async throws -> ReviewPage {
        let response: ReviewListResponse = try await NetworkManager.shared.request(
            ReviewEndpoint.fetchReviews(storeId: storeId, next: next, limit: limit, orderBy: orderBy)
        )
        return ReviewPage(reviews: response.data, nextCursor: response.next_cursor)
    }

    func fetchReview(storeId: String, reviewId: String) async throws -> ReviewDetail {
        try await NetworkManager.shared.request(
            ReviewEndpoint.fetchReview(storeId: storeId, reviewId: reviewId)
        )
    }

    func updateReview(storeId: String, reviewId: String, request: UpdateReviewRequest) async throws -> ReviewDetail {
        try await NetworkManager.shared.request(
            ReviewEndpoint.updateReview(storeId: storeId, reviewId: reviewId, body: request)
        )
    }

    func deleteReview(storeId: String, reviewId: String) async throws {
        try await NetworkManager.shared.requestWithoutResponse(
            ReviewEndpoint.deleteReview(storeId: storeId, reviewId: reviewId)
        )
    }

    func fetchRatings(storeId: String) async throws -> [ReviewRating] {
        let response: ReviewRatingListResponse = try await NetworkManager.shared.request(
            ReviewEndpoint.fetchRatings(storeId: storeId)
        )
        return response.data
    }
}

// MARK: - Mock

final class MockReviewClient: ReviewClientProtocol {
    var uploadFilesResult: Result<[String], Error> = .success([])
    var createReviewResult: Result<ReviewDetail, Error> = .success(.mock)
    var fetchReviewsResult: Result<ReviewPage, Error> = .success(ReviewPage(reviews: [], nextCursor: "0"))
    var fetchReviewResult: Result<ReviewDetail, Error> = .success(.mock)
    var updateReviewResult: Result<ReviewDetail, Error> = .success(.mock)
    var deleteReviewResult: Result<Void, Error> = .success(())
    var fetchRatingsResult: Result<[ReviewRating], Error> = .success([])

    func uploadFiles(storeId: String, parts: [MultipartData]) async throws -> [String] { try uploadFilesResult.get() }
    func createReview(storeId: String, request: CreateReviewRequest) async throws -> ReviewDetail { try createReviewResult.get() }
    func fetchReviews(storeId: String, next: String?, limit: Int?, orderBy: String?) async throws -> ReviewPage { try fetchReviewsResult.get() }
    func fetchReview(storeId: String, reviewId: String) async throws -> ReviewDetail { try fetchReviewResult.get() }
    func updateReview(storeId: String, reviewId: String, request: UpdateReviewRequest) async throws -> ReviewDetail { try updateReviewResult.get() }
    func deleteReview(storeId: String, reviewId: String) async throws { try deleteReviewResult.get() }
    func fetchRatings(storeId: String) async throws -> [ReviewRating] { try fetchRatingsResult.get() }
}

// MARK: - Mock Data

extension ReviewDetail {
    static let mock = ReviewDetail(
        review_id: "mock-review-id",
        content: "정말 맛있었어요! 다음에도 꼭 올게요.",
        rating: 5,
        store: ReviewStoreSummary(
            id: "mock-store-id", name: "새싹 도넛 가게", category: "디저트",
            store_image_urls: [], is_picchelin: true, is_pick: false,
            pick_count: 100, total_rating: 4.8, total_review_count: 50
        ),
        review_image_urls: [],
        order_menu_list: ["올리브 그린 새싹 도넛"],
        creator: UserInfo(user_id: "user-id", nick: "테스터", profileImage: nil),
        createdAt: "",
        updatedAt: ""
    )
}
