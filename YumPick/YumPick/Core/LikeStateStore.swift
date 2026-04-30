import Foundation

@Observable
final class LikeStateStore {
    static let shared = LikeStateStore()

    private(set) var states: [String: Bool] = [:]

    private init() {}

    func update(storeId: String, isLiked: Bool) {
        states[storeId] = isLiked
    }

    func isLiked(for storeId: String, fallback: Bool) -> Bool {
        states[storeId] ?? fallback
    }
}
