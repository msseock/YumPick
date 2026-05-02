import Foundation

// MARK: - Protocol

protocol CheckoutClientProtocol {
    func createOrder(_ request: OrderCreateRequest) async throws -> OrderCreateResponse
    func validatePayment(impUid: String) async throws -> PaymentValidationResponse
}

// MARK: - Endpoints

private enum CheckoutEndpoint: Endpoint {
    case createOrder(OrderCreateRequest)
    case validatePayment(impUid: String)

    var path: String {
        switch self {
        case .createOrder: return "/v1/orders"
        case .validatePayment: return "/v1/payments/validation"
        }
    }

    var method: HTTPMethod { .post }

    var parameters: RequestParameters {
        switch self {
        case .createOrder(let request): return .body(request)
        case .validatePayment(let impUid): return .body(PaymentValidationRequest(imp_uid: impUid))
        }
    }
}

// MARK: - Real Implementation

final class CheckoutClient: CheckoutClientProtocol {
    func createOrder(_ request: OrderCreateRequest) async throws -> OrderCreateResponse {
        try await NetworkManager.shared.request(CheckoutEndpoint.createOrder(request))
    }

    func validatePayment(impUid: String) async throws -> PaymentValidationResponse {
        try await NetworkManager.shared.request(CheckoutEndpoint.validatePayment(impUid: impUid))
    }
}

// MARK: - Mock

final class MockCheckoutClient: CheckoutClientProtocol {
    var createOrderResult: Result<OrderCreateResponse, Error> = .success(
        OrderCreateResponse(
            order_id: "mock-order-id",
            order_code: "mock-order-code",
            total_price: 9600,
            createdAt: "",
            updatedAt: ""
        )
    )
    var validatePaymentResult: Result<PaymentValidationResponse, Error> = .success(
        PaymentValidationResponse(
            payment_id: "mock-payment-id",
            order_item: PaymentOrderItem(
                order_id: "mock-order-id",
                order_code: "mock-order-code",
                total_price: 9600
            ),
            createdAt: "",
            updatedAt: ""
        )
    )

    func createOrder(_ request: OrderCreateRequest) async throws -> OrderCreateResponse {
        try createOrderResult.get()
    }

    func validatePayment(impUid: String) async throws -> PaymentValidationResponse {
        try validatePaymentResult.get()
    }
}
