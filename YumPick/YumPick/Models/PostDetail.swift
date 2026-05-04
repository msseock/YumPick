import Foundation

struct PostDetail: Codable, Identifiable {
    let post_id: String
    let category: String
    let title: String
    let content: String
    let store: PostStore?
    let geolocation: Geolocation
    let creator: PostCreator
    let files: [String]
    let is_like: Bool
    let like_count: Double
    let comments: [PostComment]
    let createdAt: String
    let updatedAt: String

    var id: String { post_id }
}
