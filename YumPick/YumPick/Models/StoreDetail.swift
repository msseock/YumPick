import Foundation

struct StoreDetail: Codable, Identifiable, Hashable {
    let store_id: String
    let category: String?
    let name: String?
    let description: String?
    let hashTags: [String]
    let open: String?
    let close: String?
    let address: String?
    let estimated_pickup_time: Int
    let parking_guide: String?
    let store_image_urls: [String]
    let is_picchelin: Bool
    let is_pick: Bool
    let pick_count: Int
    let total_review_count: Int
    let total_order_count: Int
    let total_rating: Double
    let creator: UserInfo
    let geolocation: Geolocation
    let menu_list: [StoreMenu]
    let createdAt: String
    let updatedAt: String

    var id: String { store_id }
}
