import Foundation

struct Review: Codable, Identifiable {
    let review_id: String
    let content: String
    let rating: Int
    let review_image_urls: [String]
    let order_menu_list: [String]
    let creator: UserInfo
    let user_total_review_count: Int
    let user_total_rating: Float
    let createdAt: String
    let updatedAt: String

    var id: String { review_id }
}

struct ReviewDetail: Codable, Identifiable {
    let review_id: String
    let content: String
    let rating: Int
    let store: ReviewStoreSummary
    let review_image_urls: [String]
    let order_menu_list: [String]
    let creator: UserInfo
    let createdAt: String
    let updatedAt: String

    var id: String { review_id }
}

struct ReviewStoreSummary: Codable {
    let id: String?
    let name: String?
    let category: String?
    let store_image_urls: [String]?
    let is_picchelin: Bool?
    let is_pick: Bool?
    let pick_count: Int?
    let total_rating: Float?
    let total_review_count: Int?
}

struct ReviewRating: Codable {
    let rating: Int
    let count: Int
}
