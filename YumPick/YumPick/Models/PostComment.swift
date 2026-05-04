import Foundation

struct PostComment: Codable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: PostCreator
    let replies: [PostReply]

    var id: String { comment_id }
}

struct PostReply: Codable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: PostCreator

    var id: String { comment_id }
}
