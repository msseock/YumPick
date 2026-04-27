import Foundation

struct StoreSummary: Codable, Identifiable, Hashable {
    let store_id: String
    let category: String?
    let name: String?
    let close: String?
    let store_image_urls: [String]?
    let is_picchelin: Bool?
    let is_pick: Bool?
    let pick_count: Int?
    let hashTags: [String]?
    let total_rating: Double?
    let total_order_count: Int?
    let total_review_count: Int?
    let geolocation: Geolocation?
    let distance: Double?
    let createdAt: String?
    let updatedAt: String?

    var id: String { store_id }
}
