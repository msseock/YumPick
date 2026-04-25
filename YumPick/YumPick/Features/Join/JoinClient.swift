import Foundation

// MARK: - Protocol

protocol JoinClientProtocol {
    func validateEmail(_ email: String) async throws
    func join(email: String, password: String, nick: String) async throws -> AuthTokenBundle
}

// MARK: - Endpoint

private enum JoinEndpoint: Endpoint {
    case validateEmail(String)
    case join(JoinRequest)

    var path: String {
        switch self {
        case .validateEmail: return "/v1/users/validation/email"
        case .join:          return "/v1/users/join"
        }
    }

    var method: HTTPMethod {
        .post
    }

    var parameters: RequestParameters {
        switch self {
        case .validateEmail(let email):
            return .body(EmailValidationRequest(email: email))
        case .join(let body):
            return .body(body)
        }
    }

    var requiresAuthorization: Bool { false }
}

// MARK: - Request / Response DTOs

private struct EmailValidationRequest: Encodable {
    let email: String
}

private struct JoinRequest: Encodable {
    let email: String
    let password: String
    let nick: String
}

private struct JoinResponse: Decodable {
    let user_id: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
}

// MARK: - Real Implementation

final class JoinClient: JoinClientProtocol {
    func validateEmail(_ email: String) async throws {
        struct MessageResponse: Decodable { let message: String }
        _ = try await NetworkManager.shared.request(
            JoinEndpoint.validateEmail(email),
            responseType: MessageResponse.self
        )
    }

    func join(email: String, password: String, nick: String) async throws -> AuthTokenBundle {
        let response: JoinResponse = try await NetworkManager.shared.request(
            JoinEndpoint.join(JoinRequest(email: email, password: password, nick: nick))
        )
        return AuthTokenBundle(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userID: response.user_id,
            nick: response.nick
        )
    }
}

// MARK: - Mock

final class MockJoinClient: JoinClientProtocol {
    var validateEmailResult: Result<Void, Error> = .success(())
    var joinResult: Result<AuthTokenBundle, Error> = .success(
        AuthTokenBundle(accessToken: "mock-access", refreshToken: "mock-refresh", userID: "mock-id", nick: "테스터")
    )

    func validateEmail(_ email: String) async throws {
        try validateEmailResult.get()
    }

    func join(email: String, password: String, nick: String) async throws -> AuthTokenBundle {
        try joinResult.get()
    }
}
