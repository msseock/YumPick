import Foundation

// MARK: - Protocol

protocol ProfileClientProtocol {
    func logout() async throws
}

// MARK: - Real Implementation

final class ProfileClient: ProfileClientProtocol {
    private let loginClient: LoginClientProtocol

    init(loginClient: LoginClientProtocol = LoginClient()) {
        self.loginClient = loginClient
    }

    func logout() async throws {
        try await loginClient.logout()
    }
}

// MARK: - Mock

final class MockProfileClient: ProfileClientProtocol {
    var logoutResult: Result<Void, Error> = .success(())

    func logout() async throws {
        try logoutResult.get()
    }
}
