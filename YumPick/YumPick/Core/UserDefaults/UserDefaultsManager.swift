import Foundation

final class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key: String {
        case homeCachedPopularStores = "home.cache.popular_stores"
        case homeCachedNearbyFirstPage = "home.cache.nearby_stores_first_page"
    }

    // MARK: - Variables

    var homeCachedPopularStores: [StoreSummary]? {
        get { decode(.homeCachedPopularStores) }
        set { encode(newValue, forKey: .homeCachedPopularStores) }
    }

    var homeCachedNearbyFirstPage: HomeNearbyFirstPageCache? {
        get { decode(.homeCachedNearbyFirstPage) }
        set { encode(newValue, forKey: .homeCachedNearbyFirstPage) }
    }

    // MARK: - Generic helpers

    private func decode<T: Decodable>(_ key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T?, forKey key: Key) {
        if let value, let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
