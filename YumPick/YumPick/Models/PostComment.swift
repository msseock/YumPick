import Foundation

struct PostComment: Codable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: PostCreator
    let replies: [PostReply]

    var id: String { comment_id }

    init(comment_id: String, content: String, createdAt: String, creator: PostCreator, replies: [PostReply]) {
        self.comment_id = comment_id
        self.content = content
        self.createdAt = createdAt
        self.creator = creator
        self.replies = replies
    }

    enum CodingKeys: String, CodingKey {
        case comment_id
        case content
        case createdAt
        case creator
        case replies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        comment_id = try container.decode(String.self, forKey: .comment_id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        creator = try container.decode(PostCreator.self, forKey: .creator)
        replies = try container.decodeIfPresent([PostReply].self, forKey: .replies) ?? []
    }
}

struct PostReply: Codable, Identifiable {
    let comment_id: String
    let content: String
    let createdAt: String
    let creator: PostCreator

    var id: String { comment_id }
}
