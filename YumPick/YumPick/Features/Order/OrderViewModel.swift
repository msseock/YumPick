import Foundation

@Observable
final class OrderViewModel {
    var orders: [Order] = []
    var isLoading = false
    var isUpdatingStatus = false
    var errorMessage: String? = nil

    private let client: OrderClientProtocol

    init(client: OrderClientProtocol = OrderClient()) {
        self.client = client
    }

    func fetchOrders() async {
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await client.fetchOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func advanceStatus(of order: Order) async {
        guard let next = nextStatus(from: order.current_order_status) else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        do {
            try await client.updateOrderStatus(orderCode: order.order_code, nextStatus: next)
            await fetchOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func nextStatus(from current: String) -> String? {
        switch current {
        case "PENDING_APPROVAL": return "APPROVED"
        case "APPROVED":         return "IN_PROGRESS"
        case "IN_PROGRESS":      return "READY_FOR_PICKUP"
        case "READY_FOR_PICKUP": return "PICKED_UP"
        default:                 return nil
        }
    }
}
