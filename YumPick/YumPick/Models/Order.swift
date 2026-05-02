import Foundation

struct Order: Codable, Identifiable {
    let order_id: String
    let order_code: String
    let total_price: Double
    let review: OrderReview?
    let store: OrderStore
    let order_menu_list: [OrderMenuItem]
    let paidAt: String
    let current_order_status: String
    let order_status_timeline: [OrderStatusTimeline]

    var id: String { order_id }
}

struct OrderReview: Codable {
    let id: String
    let rating: Double
}

struct OrderStore: Codable {
    let id: String?
    let name: String?
    let store_image_urls: [String]?
}

struct OrderMenuItem: Codable {
    let menu: OrderMenu
    let quantity: Double
}

struct OrderMenu: Codable {
    let id: String
    let name: String?
    let price: Int?
    let menu_image_url: String?
}

struct OrderStatusTimeline: Codable {
    let status: String
    let completed: Bool
    let changedAt: String?
}
