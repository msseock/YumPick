import Foundation

struct CheckoutSelection: Hashable {
    let storeId: String
    let storeName: String
    let items: [CheckoutSelectionItem]
    let totalPrice: Int
}

struct CheckoutSelectionItem: Hashable {
    let menuId: String
    let name: String
    let price: Int
    let quantity: Int

    var subtotal: Int { price * quantity }
}
