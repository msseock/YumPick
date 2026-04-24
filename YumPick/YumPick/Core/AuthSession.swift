import Foundation

/// 앱 전역 인증 상태.
/// - 화면 전환은 RootView 가, HTTP 응답 해석은 Interceptor/NetworkManager 가 담당한다.
/// - 인스턴스 하나를 YumPickApp 에서 생성해 SwiftUI Environment 로 주입한다. 싱글턴 사용 금지.
@MainActor
@Observable
final class AuthSession {
    enum State: Equatable {
        case checking
        case authenticated
        case unauthenticated
        case expired
    }

    var state: State = .checking

    private let keychain: KeychainManager

    init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
    }

    func restore() {
        let accessToken = keychain.read(key: .accessToken)
        let refreshToken = keychain.read(key: .refreshToken)
        state = (accessToken != nil && refreshToken != nil) ? .authenticated : .unauthenticated
    }

    func login(accessToken: String, refreshToken: String) {
        keychain.save(key: .accessToken, value: accessToken)
        keychain.save(key: .refreshToken, value: refreshToken)
        state = .authenticated
    }

    func logout() {
        clearTokens()
        state = .unauthenticated
    }

    func expire() {
        clearTokens()
        state = .expired
    }

    private func clearTokens() {
        keychain.delete(key: .accessToken)
        keychain.delete(key: .refreshToken)
    }
}
