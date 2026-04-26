import Foundation

// MARK: - Protocol

protocol HomeClientProtocol {
    func fetchContent() async throws
}

// MARK: - Real Implementation

final class HomeClient: HomeClientProtocol {
    func fetchContent() async throws {}
}

// MARK: - Mock

final class MockHomeClient: HomeClientProtocol {
    var fetchContentResult: Result<Void, Error> = .success(())

    func fetchContent() async throws {
        try fetchContentResult.get()
    }
}
