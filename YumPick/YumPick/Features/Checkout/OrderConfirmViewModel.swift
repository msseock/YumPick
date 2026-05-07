import Foundation

@Observable
final class OrderConfirmViewModel {

    enum Phase {
        case idle
        case checkingStock
        case stockCheckPassed
        case creatingOrder
        case paying
        case error
    }

    // MARK: - State

    let selection: CheckoutSelection
    var phase: Phase = .idle
    var errorMessage: String? = nil
    var soldOutMenuNames: [String] = []
    var createdOrder: OrderCreateResponse? = nil

    // MARK: - Dependencies

    private let storeDetailClient: StoreDetailClientProtocol
    private let checkoutClient: CheckoutClientProtocol

    init(
        selection: CheckoutSelection,
        storeDetailClient: StoreDetailClientProtocol = StoreDetailClient(),
        checkoutClient: CheckoutClientProtocol = CheckoutClient()
    ) {
        self.selection = selection
        self.storeDetailClient = storeDetailClient
        self.checkoutClient = checkoutClient
    }

    // MARK: - Actions

    func validateStock() async {
        phase = .checkingStock
        errorMessage = nil

        do {
            let detail = try await storeDetailClient.fetchStoreDetail(storeId: selection.storeId)

            let menuMap = Dictionary(uniqueKeysWithValues: detail.menu_list.map { ($0.menu_id, $0) })
            let soldOut = selection.items.compactMap { item -> String? in
                guard menuMap[item.menuId]?.is_sold_out == true else { return nil }
                return item.name
            }

            if !soldOut.isEmpty {
                soldOutMenuNames = soldOut
                phase = .idle
                return
            }

            phase = .stockCheckPassed

        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }

    func createOrderAndPay() async {
        phase = .creatingOrder
        errorMessage = nil
        
        do {
            let request = OrderCreateRequest(
                store_id: selection.storeId,
                order_menu_list: selection.items.map {
                    OrderCreateItem(menu_id: $0.menuId, quantity: $0.quantity)
                },
                total_price: selection.totalPrice
            )
            let response = try await checkoutClient.createOrder(request)
            createdOrder = response
            phase = .paying

        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }
}
