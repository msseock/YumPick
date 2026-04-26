import Foundation

// MARK: - Protocol

protocol CommunityClientProtocol {
    func fetchContent() async throws
}

// MARK: - Real Implementation

final class CommunityClient: CommunityClientProtocol {
    func fetchContent() async throws {}
}

// MARK: - Mock

final class MockCommunityClient: CommunityClientProtocol {
    var fetchContentResult: Result<Void, Error> = .success(())

    func fetchContent() async throws {
        try fetchContentResult.get()
    }
}
