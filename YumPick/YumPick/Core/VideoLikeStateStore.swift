import Foundation

@Observable
final class VideoLikeStateStore {
    static let shared = VideoLikeStateStore()

    struct State: Hashable {
        let isLiked: Bool
        let likeCount: Int
    }

    private(set) var states: [String: State] = [:]

    private init() {}

    func update(videoId: String, isLiked: Bool, likeCount: Int) {
        states[videoId] = State(isLiked: isLiked, likeCount: likeCount)
    }

    func state(for videoId: String, fallback: State) -> State {
        states[videoId] ?? fallback
    }
}
