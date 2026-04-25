import XCTest
@testable import YumPick

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    private static var _requests: [URLRequest] = []

    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { lock.withLock { _requestHandler } }
        set { lock.withLock { _requestHandler = newValue } }
    }

    static var requests: [URLRequest] {
        lock.withLock { _requests }
    }

    static var lastRequest: URLRequest? {
        lock.withLock { _requests.last }
    }

    static func reset() {
        lock.withLock {
            _requestHandler = nil
            _requests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = MockURLProtocol.lock.withLock {
            MockURLProtocol._requests.append(request)
            return MockURLProtocol._requestHandler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Helpers

// URLSession이 httpBody를 httpBodyStream으로 변환하므로 양쪽을 모두 확인
private func bodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    var data = Data()
    stream.open()
    defer { stream.close() }
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: 4096)
        guard read > 0 else { break }
        data.append(buffer, count: read)
    }
    return data
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://mock.yumpick.test")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private struct DummyResponse: Codable, Equatable {
    let id: Int
    let name: String
}

private enum DummyAPI: Endpoint {
    case fetch
    case fetchWithQuery
    case post(DummyResponse)
    case multipart
    case noAuth

    var path: String {
        switch self {
        case .fetch, .post, .multipart: return "/v1/dummy"
        case .fetchWithQuery:           return "/v1/dummy"
        case .noAuth:                   return "/v1/public"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetch, .fetchWithQuery, .noAuth: return .get
        case .post, .multipart:                return .post
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .fetch, .noAuth:       return .none
        case .fetchWithQuery:       return .query(["page": "1", "limit": "10"])
        case .post(let body):       return .body(body)
        case .multipart:
            let part = MultipartData(name: "file", fileName: "test.jpg", mimeType: "image/jpeg", data: Data("fake-image".utf8))
            return .multipart([part])
        }
    }

    var requiresAuthorization: Bool {
        self == .noAuth ? false : true
    }
}

extension DummyAPI: Equatable {
    static func == (lhs: DummyAPI, rhs: DummyAPI) -> Bool {
        switch (lhs, rhs) {
        case (.fetch, .fetch), (.noAuth, .noAuth), (.fetchWithQuery, .fetchWithQuery), (.multipart, .multipart): return true
        default: return false
        }
    }
}

private enum BadURLAPI: Endpoint {
    case bad
    var baseURL: String { "" }
    var path: String { "" }
    var method: HTTPMethod { .get }
    var parameters: RequestParameters { .none }
    var requiresAuthorization: Bool { false }
}

// MARK: - MockInterceptor

final class MockInterceptor: InterceptorProtocol {
    var adaptHandler: ((URLRequest) async throws -> URLRequest)?
    var retryHandler: ((URLRequest) async throws -> URLRequest)?

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        try await adaptHandler?(request) ?? request
    }

    func retry(_ request: URLRequest) async throws -> URLRequest {
        if let handler = retryHandler { return try await handler(request) }
        throw NetworkError.refreshTokenExpired
    }
}

// MARK: - NetworkManagerTests

final class NetworkManagerTests: XCTestCase {

    private var sut: NetworkManager!
    private var currentSession: URLSession!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        currentSession = makeMockSession()
        sut = NetworkManager(session: currentSession)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        currentSession.invalidateAndCancel()
        currentSession = nil
        sut = nil
        super.tearDown()
    }

    private func makeSut(interceptor: any InterceptorProtocol) -> (NetworkManager, URLSession) {
        let session = makeMockSession()
        let manager = NetworkManager(session: session, interceptor: interceptor)
        return (manager, session)
    }

    // MARK: 정상 응답

    func test_200응답_정상_디코딩() async throws {
        let expected = DummyResponse(id: 1, name: "얌픽")
        MockURLProtocol.requestHandler = { _ in
            (makeResponse(statusCode: 200), try JSONEncoder().encode(expected))
        }

        let result: DummyResponse = try await sut.request(DummyAPI.fetch)
        XCTAssertEqual(result, expected)
    }

    func test_공통헤더_SeSACKey_포함() async throws {
        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
        let capturedRequest = MockURLProtocol.lastRequest
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "SeSACKey"), SecretConstants.sesacKey)
    }

    func test_requiresAuth_false_Authorization헤더_없음() async throws {
        // Keychain에 토큰이 있어도 requiresAuth=false면 Authorization 헤더 미포함
        KeychainManager.shared.save(key: .accessToken, value: "test-token")
        defer { KeychainManager.shared.delete(key: .accessToken) }

        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
        let capturedRequest = MockURLProtocol.lastRequest
        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_requiresAuth_true_Authorization헤더_포함() async throws {
        KeychainManager.shared.save(key: .accessToken, value: "my-access-token")
        defer { KeychainManager.shared.delete(key: .accessToken) }

        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.fetch)
        let capturedRequest = MockURLProtocol.lastRequest
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "my-access-token")
    }

    // MARK: 쿼리 파라미터

    func test_쿼리파라미터_URL에_포함() async throws {
        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.fetchWithQuery)
        let capturedRequest = MockURLProtocol.lastRequest
        let urlString = capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("page=1"))
        XCTAssertTrue(urlString.contains("limit=10"))
    }

    // MARK: 에러 매핑

    func test_401응답_unauthorized_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 401), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.unauthorized {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_403응답_forbidden_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 403), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.forbidden {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_420응답_invalidKey_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 420), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.invalidKey {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_429응답_rateLimited_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 429), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.rateLimited {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_500응답_serverError_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 500), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.serverError {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_미정의_4xx응답_clientError_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 445), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.clientError(let code) {
            XCTAssertEqual(code, 445)
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_잘못된_JSON_decodingError() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 200), Data("invalid".utf8)) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.decodingError {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: POST body / multipart

    func test_POST_body_httpBody에_인코딩됨() async throws {
        let body = DummyResponse(id: 42, name: "바디테스트")
        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(body))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.post(body))
        let request = try XCTUnwrap(MockURLProtocol.lastRequest)
        let data = try XCTUnwrap(bodyData(from: request))
        let decoded = try JSONDecoder().decode(DummyResponse.self, from: data)
        XCTAssertEqual(decoded, body)
    }

    func test_multipart_ContentType에_boundary_포함() async throws {
        MockURLProtocol.requestHandler = { _ in
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await sut.request(DummyAPI.multipart)
        let capturedRequest = MockURLProtocol.lastRequest
        let contentType = capturedRequest?.value(forHTTPHeaderField: "Content-Type") ?? ""
        XCTAssertTrue(contentType.contains("multipart/form-data"))
        XCTAssertTrue(contentType.contains("boundary="))
    }

    // MARK: 추가 에러 매핑

    func test_444응답_invalidRequest_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 444), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.invalidRequest {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_5xx_500외_응답_unknown_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 503), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.unknown {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_잘못된URL_invalidURL_에러() async {
        do {
            let _: DummyResponse = try await sut.request(BadURLAPI.bad)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.invalidURL {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: 419 - 액세스 토큰 만료 → 자동 갱신 후 재시도

    func test_419응답_tokenExpired_재시도_후_성공() async throws {
        let mockInterceptor = MockInterceptor()
        mockInterceptor.retryHandler = { request in
            var r = request
            r.setValue("new-token", forHTTPHeaderField: "Authorization")
            return r
        }
        let (localSut, session) = makeSut(interceptor: mockInterceptor)
        defer { session.invalidateAndCancel() }

        let expected = DummyResponse(id: 99, name: "갱신후")
        MockURLProtocol.requestHandler = { _ in
            if MockURLProtocol.requests.count == 1 {
                return (makeResponse(statusCode: 419), Data())
            }
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(expected))
        }

        let result: DummyResponse = try await localSut.request(DummyAPI.fetch)
        XCTAssertEqual(result, expected)
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }

    func test_419응답_retry_갱신후_Authorization헤더_교체됨() async throws {
        let mockInterceptor = MockInterceptor()
        mockInterceptor.retryHandler = { request in
            var r = request
            r.setValue("refreshed-token", forHTTPHeaderField: "Authorization")
            return r
        }
        let (localSut, session) = makeSut(interceptor: mockInterceptor)
        defer { session.invalidateAndCancel() }

        MockURLProtocol.requestHandler = { _ in
            if MockURLProtocol.requests.count == 1 {
                return (makeResponse(statusCode: 419), Data())
            }
            return (makeResponse(statusCode: 200), try JSONEncoder().encode(DummyResponse(id: 1, name: "test")))
        }

        let _: DummyResponse = try await localSut.request(DummyAPI.fetch)
        let secondRequest = MockURLProtocol.requests.dropFirst().first
        XCTAssertEqual(secondRequest?.value(forHTTPHeaderField: "Authorization"), "refreshed-token")
    }

    // MARK: requestWithoutResponse

    func test_requestWithoutResponse_200_성공() async throws {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 200), Data()) }
        try await sut.requestWithoutResponse(DummyAPI.fetch)
        // 에러 없이 완료되면 성공
    }

    func test_requestWithoutResponse_401_unauthorized_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 401), Data()) }

        do {
            try await sut.requestWithoutResponse(DummyAPI.fetch)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.unauthorized {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    func test_requestWithoutResponse_419_재시도_후_성공() async throws {
        let mockInterceptor = MockInterceptor()
        mockInterceptor.retryHandler = { $0 }
        let (localSut, session) = makeSut(interceptor: mockInterceptor)
        defer { session.invalidateAndCancel() }

        MockURLProtocol.requestHandler = { _ in
            return MockURLProtocol.requests.count == 1
                ? (makeResponse(statusCode: 419), Data())
                : (makeResponse(statusCode: 200), Data())
        }

        try await localSut.requestWithoutResponse(DummyAPI.fetch)
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }

    func test_requestWithoutResponse_418_refreshTokenExpired_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 418), Data()) }

        do {
            try await sut.requestWithoutResponse(DummyAPI.fetch)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.refreshTokenExpired {
            // 통과
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }

    // MARK: 418 - 리프레시 토큰 만료

    func test_418응답_refreshTokenExpired_에러() async {
        MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 418), Data()) }

        do {
            let _: DummyResponse = try await sut.request(DummyAPI.noAuth)
            XCTFail("에러가 발생해야 합니다")
        } catch NetworkError.refreshTokenExpired {
            // 통과 — 세션 만료 콜백은 Interceptor.retry() 에서 처리됨
        } catch {
            XCTFail("예상하지 못한 에러: \(error)")
        }
    }
}
