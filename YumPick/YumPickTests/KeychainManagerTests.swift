import XCTest
@testable import YumPick

final class KeychainManagerTests: XCTestCase {

    private let keychain = KeychainManager.shared

    override func tearDown() {
        keychain.deleteAll()
        super.tearDown()
    }

    func test_accessToken_저장_및_조회() {
        keychain.save(key: .accessToken, value: "test-access-token")
        XCTAssertEqual(keychain.read(key: .accessToken), "test-access-token")
    }

    func test_refreshToken_저장_및_조회() {
        keychain.save(key: .refreshToken, value: "test-refresh-token")
        XCTAssertEqual(keychain.read(key: .refreshToken), "test-refresh-token")
    }

    func test_덮어쓰기_최신값_반환() {
        keychain.save(key: .accessToken, value: "old-token")
        keychain.save(key: .accessToken, value: "new-token")
        XCTAssertEqual(keychain.read(key: .accessToken), "new-token")
    }

    func test_삭제_후_nil_반환() {
        keychain.save(key: .accessToken, value: "token")
        keychain.delete(key: .accessToken)
        XCTAssertNil(keychain.read(key: .accessToken))
    }

    func test_저장_안한_키_nil_반환() {
        XCTAssertNil(keychain.read(key: .accessToken))
    }

    func test_deleteAll_모든_토큰_삭제() {
        keychain.save(key: .accessToken, value: "access")
        keychain.save(key: .refreshToken, value: "refresh")
        keychain.deleteAll()
        XCTAssertNil(keychain.read(key: .accessToken))
        XCTAssertNil(keychain.read(key: .refreshToken))
    }
}
