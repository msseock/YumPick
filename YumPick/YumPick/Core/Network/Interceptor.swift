import Foundation

protocol InterceptorProtocol {
    func adapt(_ request: URLRequest) async throws -> URLRequest
    func retry(_ request: URLRequest) async throws -> URLRequest
    func refreshTokens() async throws -> RefreshedAuthTokens
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
        let newTokens = try await refreshTokens()

        var retryRequest = request
        retryRequest.setValue(newTokens.accessToken, forHTTPHeaderField: "Authorization")
        return retryRequest
    }

    func refreshTokens() async throws -> RefreshedAuthTokens {
        guard let refreshToken = keychain.read(key: .refreshToken) else {
            await onSessionExpired()
            throw NetworkError.refreshTokenExpired
        }

        guard let accessToken = keychain.read(key: .accessToken) else {
            await onSessionExpired()
            throw NetworkError.refreshTokenExpired
        }

        let newTokens = try await refreshAccessToken(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
        
        keychain.save(key: .accessToken, value: newTokens.accessToken)
        keychain.save(key: .refreshToken, value: newTokens.refreshToken)
        return newTokens
    }

    private func refreshAccessToken(
        accessToken: String,
        refreshToken: String
    ) async throws -> RefreshedAuthTokens {
        guard let url = URL(string: SecretConstants.baseURL + "/v1/auth/refresh") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        request.setValue(refreshToken, forHTTPHeaderField: "RefreshToken")
        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")

        #if DEBUG
        logRefreshRequest(request)
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
        logRefreshResponse(httpResponse, data: data)
        #endif

        let status = HTTPStatusCode(rawValue: httpResponse.statusCode)
        switch status {
        case .ok:
            return try JSONDecoder().decode(RefreshedAuthTokens.self, from: data)
        case .unauthorized, .refreshTokenExpired:
            await onSessionExpired()
            throw NetworkError.refreshTokenExpired
        default:
            throw NetworkError.unknown
        }
    }

    #if DEBUG
    private func logRefreshRequest(_ request: URLRequest) {
        print("\n--- 🔄 [REFRESH TOKEN REQUEST] ---")
        print("URL: \(request.url?.absoluteString ?? "Invalid URL")")
        print("Method: \(request.httpMethod ?? "N/A")")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("Headers: \(headers)")
        }
        print("----------------------------------\n")
    }

    private func logRefreshResponse(_ response: HTTPURLResponse, data: Data) {
        print("\n--- 🔄 [REFRESH TOKEN RESPONSE] ---")
        print("Status Code: \(response.statusCode)")
        if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
            print("Data: \(responseString)")
        } else {
            print("Data: (Empty or non-textual)")
        }
        print("-----------------------------------\n")
    }
    #endif
}

struct RefreshedAuthTokens: Decodable {
    let accessToken: String
    let refreshToken: String
}
