import Foundation

// MARK: - Protocol

protocol PaymentClientProtocol {
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt
}

// MARK: - Endpoints

private enum PaymentEndpoint: Endpoint {
    case receipt(orderCode: String)

    var path: String {
        switch self {
        case .receipt(let code): return "/v1/payments/\(code)"
        }
    }

    var method: HTTPMethod { .get }

    var parameters: RequestParameters { .none }
}

// MARK: - Real Implementation

final class PaymentClient: PaymentClientProtocol {
    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt {
        try await NetworkManager.shared.request(PaymentEndpoint.receipt(orderCode: orderCode))
    }
}

// MARK: - Mock

final class MockPaymentClient: PaymentClientProtocol {
    var fetchReceiptResult: Result<PaymentReceipt, Error> = .success(.sample)

    func fetchReceipt(orderCode: String) async throws -> PaymentReceipt {
        try fetchReceiptResult.get()
    }
}
