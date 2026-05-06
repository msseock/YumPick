import Foundation

struct Video: Codable, Identifiable, Hashable {
    let video_id: String
    let file_name: String
    let title: String
    let description: String
    let duration: Double
    let thumbnail_url: String
    let available_qualities: [String]
    let view_count: Int
    let like_count: Int
    let is_liked: Bool
    let createdAt: String

    var id: String { video_id }
}

struct VideoPage: Hashable {
    let videos: [Video]
    let nextCursor: String?
}
