import Foundation

@Observable
final class PostLikeStateStore {
    static let shared = PostLikeStateStore()

    private(set) var states: [String: Bool] = [:]

    private init() {}

    func update(postId: String, isLiked: Bool) {
        states[postId] = isLiked
    }

    func isLiked(for postId: String, fallback: Bool) -> Bool {
        states[postId] ?? fallback
    }
}
