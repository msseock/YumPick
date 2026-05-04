import Foundation

struct PostSummary: Codable, Identifiable {
    let post_id: String
    let category: String
    let title: String
    let content: String
    let store: PostStore?
    let geolocation: Geolocation?
    let creator: PostCreator
    let files: [String]
    let is_like: Bool
    let like_count: Double
    let createdAt: String
    let updatedAt: String

    var id: String { post_id }
}

struct PostStore: Codable {
    let id: String?
    let category: String?
    let name: String?
    let close: String?
    let store_image_urls: [String]?
    let is_picchelin: Bool?
    let is_pick: Bool?
    let pick_count: Int?
    let hashTags: [String]?
    let total_rating: Float?
    let total_order_count: Int?
    let total_review_count: Int?
    let geolocation: Geolocation?
}

struct PostCreator: Codable {
    let user_id: String
    let nick: String
    let profileImage: String?
}
