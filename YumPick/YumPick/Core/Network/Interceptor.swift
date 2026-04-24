import Foundation

protocol InterceptorProtocol {
    func adapt(_ request: URLRequest) async throws -> URLRequest
    func retry(_ request: URLRequest) async throws -> URLRequest
}

final class Interceptor: InterceptorProtocol {
    private let keychain: KeychainManager
    private let onSessionExpired: @Sendable () async -> Void

    init(
        keychain: KeychainManager = .shared,
        onSessionExpired: @escaping @Sendable () async -> Void = {}
    ) {
        self.keychain = keychain
        self.onSessionExpired = onSessionExpired
    }

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let accessToken = keychain.read(key: .accessToken) {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // 419 응답 시 리프레시 토큰으로 액세스 토큰 갱신 후 재요청용 URLRequest 반환
    func retry(_ request: URLRequest) async throws -> URLRequest {
        guard let refreshToken = keychain.read(key: .refreshToken) else {
            await onSessionExpired()
            throw NetworkError.refreshTokenExpired
        }

        let newTokens = try await refreshAccessToken(refreshToken: refreshToken)
        keychain.save(key: .accessToken, value: newTokens.accessToken)
        keychain.save(key: .refreshToken, value: newTokens.refreshToken)

        var retryRequest = request
        retryRequest.setValue(newTokens.accessToken, forHTTPHeaderField: "Authorization")
        return retryRequest
    }

    private func refreshAccessToken(refreshToken: String) async throws -> RefreshTokenResponse {
        guard let url = URL(string: SecretConstants.baseURL + "/v1/auth/refresh") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(refreshToken, forHTTPHeaderField: "RefreshToken")
        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        let status = HTTPStatusCode(rawValue: httpResponse.statusCode)
        switch status {
        case .ok:
            return try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
        case .unauthorized:
            throw NetworkError.unauthorized
        case .refreshTokenExpired:
            await onSessionExpired()
            throw NetworkError.refreshTokenExpired
        default:
            throw NetworkError.unknown
        }
    }
}

private struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
