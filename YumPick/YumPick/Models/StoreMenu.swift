import Foundation

struct StoreMenu: Codable, Identifiable, Hashable {
    let menu_id: String
    let store_id: String
    let category: String?
    let name: String?
    let description: String?
    let origin_information: String?
    let price: Int?
    let is_sold_out: Bool
    let tags: [String]
    let menu_image_url: String?
    let createdAt: String
    let updatedAt: String

    var id: String { menu_id }
}
