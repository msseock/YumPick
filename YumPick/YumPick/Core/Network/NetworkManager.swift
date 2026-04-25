//
//  NetworkManager.swift
//  YumPick
//
//  Created by 석민솔 on 4/23/26.
//

import Foundation

final class NetworkManager {
    static let shared = NetworkManager()
    private let session: URLSession
    private var interceptor: any InterceptorProtocol

    private init() {
        self.session = URLSession.shared
        self.interceptor = Interceptor()
    }

    // 테스트용
    init(session: URLSession, interceptor: any InterceptorProtocol = Interceptor()) {
        self.session = session
        self.interceptor = interceptor
    }

    /// 앱 시작 시 세션 만료 핸들러를 주입. AuthSession.expire 를 MainActor 에서 호출.
    @MainActor
    static func configure(onSessionExpired: @escaping @Sendable () async -> Void) {
        shared.interceptor = Interceptor(onSessionExpired: onSessionExpired)
    }

    func request<T: Decodable>(
        _ endpoint: any Endpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        var urlRequest = try buildRequest(from: endpoint)

        if endpoint.requiresAuthorization {
            urlRequest = try await interceptor.adapt(urlRequest)
        }

        #if DEBUG
        logRequest(urlRequest)
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)
            #if DEBUG
            logResponse(response, data: data)
            #endif
            try validate(response: response, data: data)
            return try decode(T.self, from: data)
        } catch NetworkError.tokenExpired {
            // 419 → 토큰 갱신 후 재시도
            urlRequest = try await interceptor.retry(urlRequest)
            #if DEBUG
            print("🔄 Retrying request after token refresh...")
            logRequest(urlRequest)
            #endif
            let (data, response) = try await session.data(for: urlRequest)
            #if DEBUG
            logResponse(response, data: data)
            #endif
            try validate(response: response, data: data)
            return try decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Network Request Error: \(error)")
            #endif
            throw error
        }
    }

    // 응답 본문이 없는 요청 (DELETE 등)
    func requestWithoutResponse(_ endpoint: any Endpoint) async throws {
        var urlRequest = try buildRequest(from: endpoint)

        if endpoint.requiresAuthorization {
            urlRequest = try await interceptor.adapt(urlRequest)
        }

        #if DEBUG
        logRequest(urlRequest)
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)
            #if DEBUG
            logResponse(response, data: data)
            #endif
            try validate(response: response, data: data)
        } catch NetworkError.tokenExpired {
            urlRequest = try await interceptor.retry(urlRequest)
            #if DEBUG
            print("🔄 Retrying request after token refresh...")
            logRequest(urlRequest)
            #endif
            let (data, response) = try await session.data(for: urlRequest)
            #if DEBUG
            logResponse(response, data: data)
            #endif
            try validate(response: response, data: data)
        } catch {
            #if DEBUG
            print("❌ Network Request Error: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Private

    #if DEBUG
    private func logRequest(_ request: URLRequest) {
        print("\n--- 🚀 [OUTGOING REQUEST] ---")
        print("URL: \(request.url?.absoluteString ?? "Invalid URL")")
        print("Method: \(request.httpMethod ?? "N/A")")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("-----------------------------\n")
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        print("\n--- ✅ [INCOMING RESPONSE] ---")
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
        }
        if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
            print("Data: \(responseString)")
        } else {
            print("Data: (Empty or non-textual)")
        }
        print("------------------------------\n")
    }
    #endif

    private func buildRequest(from endpoint: any Endpoint) throws -> URLRequest {
        guard let url = URL(string: endpoint.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        endpoint.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        switch endpoint.parameters {
        case .query(let params):
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let resolvedURL = components?.url {
                request.url = resolvedURL
            }

        case .body(let encodable):
            request.httpBody = try JSONEncoder().encode(encodable)

        case .multipart(let parts):
            let boundary = UUID().uuidString
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = buildMultipartBody(parts: parts, boundary: boundary)

        case .none:
            break
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        let status = HTTPStatusCode(rawValue: httpResponse.statusCode)
        if status?.isSuccess == true { return }

        switch status {
        case .unauthorized:         throw NetworkError.unauthorized
        case .forbidden:            throw NetworkError.forbidden
        case .refreshTokenExpired:
            throw NetworkError.refreshTokenExpired
        case .tokenExpired:         throw NetworkError.tokenExpired
        case .invalidKey:           throw NetworkError.invalidKey
        case .rateLimited:          throw NetworkError.rateLimited
        case .invalidRequest:       throw NetworkError.invalidRequest
        case .serverError:          throw NetworkError.serverError
        default:
            let code = httpResponse.statusCode
            if (400..<500).contains(code) { throw NetworkError.clientError(code) }
            throw NetworkError.unknown
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            #if DEBUG
            print("⚠️ Decoding Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed Data: \(jsonString)")
            }
            #endif
            throw NetworkError.decodingError
        }
    }

    private func buildMultipartBody(parts: [MultipartData], boundary: String) -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n")
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let fileName = part.fileName {
                disposition += "; filename=\"\(fileName)\""
            }
            body.append("\(disposition)\r\n")
            body.append("Content-Type: \(part.mimeType)\r\n\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
