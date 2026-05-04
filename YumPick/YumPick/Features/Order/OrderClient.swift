import Foundation

// MARK: - Protocol

protocol OrderClientProtocol {
    func fetchOrders() async throws -> [Order]
    func updateOrderStatus(orderCode: String, nextStatus: String) async throws
}

// MARK: - Endpoints

private enum OrderEndpoint: Endpoint {
    case orders
    case updateStatus(orderCode: String, nextStatus: String)

    var path: String {
        switch self {
        case .orders:                        return "/v1/orders"
        case .updateStatus(let code, _):     return "/v1/orders/\(code)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .orders:        return .get
        case .updateStatus:  return .put
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .orders:
            return .none
        case .updateStatus(_, let nextStatus):
            return .body(UpdateOrderStatusRequest(nextStatus: nextStatus))
        }
    }
}

// MARK: - Request / Response DTOs

private struct UpdateOrderStatusRequest: Encodable {
    let nextStatus: String
}

private struct OrdersResponse: Decodable {
    let data: [Order]
}

// MARK: - Real Implementation

final class OrderClient: OrderClientProtocol {
    func fetchOrders() async throws -> [Order] {
        let response: OrdersResponse = try await NetworkManager.shared.request(OrderEndpoint.orders)
        return response.data
    }

    func updateOrderStatus(orderCode: String, nextStatus: String) async throws {
        try await NetworkManager.shared.requestWithoutResponse(
            OrderEndpoint.updateStatus(orderCode: orderCode, nextStatus: nextStatus)
        )
    }
}

// MARK: - Mock

final class MockOrderClient: OrderClientProtocol {
    var fetchOrdersResult: Result<[Order], Error> = .success([])
    var updateOrderStatusResult: Result<Void, Error> = .success(())

    func fetchOrders() async throws -> [Order] {
        try fetchOrdersResult.get()
    }

    func updateOrderStatus(orderCode: String, nextStatus: String) async throws {
        try updateOrderStatusResult.get()
    }
}
