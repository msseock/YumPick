import Foundation

@Observable
final class OrderViewModel {
    var orders: [Order] = []
    var isLoading = false
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
}
