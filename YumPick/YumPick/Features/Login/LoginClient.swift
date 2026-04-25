import Foundation

// MARK: - Protocol

protocol LoginClientProtocol {
    func login(email: String, password: String) async throws -> AuthTokenBundle
    func logout() async throws
}

// MARK: - Endpoints

private enum LoginEndpoint: Endpoint {
    case login(LoginRequest)
    case logout

    var path: String {
        switch self {
        case .login:  return "/v1/users/login"
        case .logout: return "/v1/users/logout"
        }
    }

    var method: HTTPMethod { .post }

    var parameters: RequestParameters {
        switch self {
        case .login(let body): return .body(body)
        case .logout:          return .none
        }
    }

    var requiresAuthorization: Bool {
        switch self {
        case .login:  return false
        case .logout: return true
        }
    }
}

// MARK: - DTOs

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct LoginResponse: Decodable {
    let user_id: String
    let nick: String
    let accessToken: String
    let refreshToken: String
}

// MARK: - Real Implementation

final class LoginClient: LoginClientProtocol {
    func login(email: String, password: String) async throws -> AuthTokenBundle {
        let response: LoginResponse = try await NetworkManager.shared.request(
            LoginEndpoint.login(LoginRequest(email: email, password: password))
        )
        return AuthTokenBundle(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userID: response.user_id,
            nick: response.nick
        )
    }

    func logout() async throws {
        try await NetworkManager.shared.requestWithoutResponse(LoginEndpoint.logout)
    }
}

// MARK: - Mock

final class MockLoginClient: LoginClientProtocol {
    var loginResult: Result<AuthTokenBundle, Error> = .success(
        AuthTokenBundle(accessToken: "mock-access", refreshToken: "mock-refresh", userID: "mock-id", nick: "테스터")
    )
    var logoutResult: Result<Void, Error> = .success(())

    func login(email: String, password: String) async throws -> AuthTokenBundle {
        try loginResult.get()
    }

    func logout() async throws {
        try logoutResult.get()
    }
}
