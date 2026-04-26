import Foundation

// MARK: - Protocol

protocol OrderClientProtocol {
    func fetchContent() async throws
}

// MARK: - Real Implementation

final class OrderClient: OrderClientProtocol {
    func fetchContent() async throws {}
}

// MARK: - Mock

final class MockOrderClient: OrderClientProtocol {
    var fetchContentResult: Result<Void, Error> = .success(())

    func fetchContent() async throws {
        try fetchContentResult.get()
    }
}
