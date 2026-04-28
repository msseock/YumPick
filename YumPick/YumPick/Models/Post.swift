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
    let name: String?
    let store_image_urls: [String]?
}

struct PostCreator: Codable {
    let user_id: String
    let nick: String
    let profileImage: String?
}
