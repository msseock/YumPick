import Foundation

final class ChatFileNameCache {
    static let shared = ChatFileNameCache()
    private init() {}

    private var cache: [String: String] = [:]
    private let lock = NSLock()

    func set(path: String, originalName: String) {
        lock.lock(); defer { lock.unlock() }
        cache[path] = originalName
    }

    func displayName(for path: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[path] { return cached }
        return (path as NSString).lastPathComponent
    }
}
