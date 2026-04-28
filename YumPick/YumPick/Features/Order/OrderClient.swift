import Foundation

// MARK: - Protocol

protocol OrderClientProtocol {
    func fetchOrders() async throws -> [Order]
}

// MARK: - Endpoints

private enum OrderEndpoint: Endpoint {
    case orders

    var path: String { "/v1/orders" }
    var method: HTTPMethod { .get }
    var parameters: RequestParameters { .none }
}

// MARK: - Response DTOs

private struct OrdersResponse: Decodable {
    let data: [Order]
}

// MARK: - Real Implementation

final class OrderClient: OrderClientProtocol {
    func fetchOrders() async throws -> [Order] {
        let response: OrdersResponse = try await NetworkManager.shared.request(OrderEndpoint.orders)
        return response.data
    }
}

// MARK: - Mock

final class MockOrderClient: OrderClientProtocol {
    var fetchOrdersResult: Result<[Order], Error> = .success([])

    func fetchOrders() async throws -> [Order] {
        try fetchOrdersResult.get()
    }
}
