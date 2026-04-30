import Foundation

// MARK: - 주문 생성

struct OrderCreateRequest: Encodable {
    let store_id: String
    let order_menu_list: [OrderCreateItem]
    let total_price: Int
}

struct OrderCreateItem: Encodable {
    let menu_id: String
    let quantity: Int
}

struct OrderCreateResponse: Decodable {
    let order_id: String
    let order_code: String
    let total_price: Int
    let createdAt: String
    let updatedAt: String
}

// MARK: - 결제 영수증 검증

struct PaymentValidationRequest: Encodable {
    let imp_uid: String
}

struct PaymentValidationResponse: Decodable {
    let payment_id: String
    let order_item: PaymentOrderItem
    let createdAt: String
    let updatedAt: String
}

struct PaymentOrderItem: Decodable {
    let order_id: String
    let order_code: String
    let total_price: Double
}
