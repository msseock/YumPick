import Foundation

// MARK: - Protocol

protocol PickClientProtocol {
    func fetchContent() async throws
}

// MARK: - Real Implementation

final class PickClient: PickClientProtocol {
    func fetchContent() async throws {}
}

// MARK: - Mock

final class MockPickClient: PickClientProtocol {
    var fetchContentResult: Result<Void, Error> = .success(())

    func fetchContent() async throws {
        try fetchContentResult.get()
    }
}
