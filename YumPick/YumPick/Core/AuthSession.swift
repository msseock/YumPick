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
    private(set) var userID: String?
    private(set) var nick: String?

    private let keychain: KeychainManager

    init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
    }

    func restore() {
        let accessToken = keychain.read(key: .accessToken)
        let refreshToken = keychain.read(key: .refreshToken)
        self.userID = keychain.read(key: .userID)
        self.nick = keychain.read(key: .nick)
        state = (accessToken != nil && refreshToken != nil) ? .authenticated : .unauthenticated
    }

    func login(tokens: AuthTokenBundle) {
        keychain.save(key: .accessToken, value: tokens.accessToken)
        keychain.save(key: .refreshToken, value: tokens.refreshToken)
        keychain.save(key: .userID, value: tokens.userID)
        keychain.save(key: .nick, value: tokens.nick)
        
        self.userID = tokens.userID
        self.nick = tokens.nick
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
        keychain.delete(key: .userID)
        keychain.delete(key: .nick)
        self.userID = nil
        self.nick = nil
    }
}
