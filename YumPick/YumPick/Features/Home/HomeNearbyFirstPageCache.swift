import Foundation

struct HomeNearbyFirstPageCache: Codable {
    let stores: [StoreSummary]
    let nextCursor: String?
    let sort: String
}
