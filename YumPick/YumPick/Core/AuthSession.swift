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

    func restore() async {
        let accessToken = keychain.read(key: .accessToken)
        let refreshToken = keychain.read(key: .refreshToken)
        self.userID = keychain.read(key: .userID)
        self.nick = keychain.read(key: .nick)

        guard refreshToken != nil else {
            clearTokens()
            state = .unauthenticated
            return
        }

        guard let userID, let nick else {
            clearTokens()
            state = .unauthenticated
            return
        }
        UserSession.shared.set(userID: userID, nick: nick)

        if let accessToken, !accessToken.isExpiredJWT {
            state = .authenticated
            return
        }

        do {
            try await NetworkManager.shared.refreshAuthorization()
            state = .authenticated
        } catch {
            print("AuthSession restore failed")
            clearTokens()
            state = .expired
        }
    }

    func login(tokens: AuthTokenBundle) {
        keychain.save(key: .accessToken, value: tokens.accessToken)
        keychain.save(key: .refreshToken, value: tokens.refreshToken)
        keychain.save(key: .userID, value: tokens.userID)
        keychain.save(key: .nick, value: tokens.nick)

        self.userID = tokens.userID
        self.nick = tokens.nick
        UserSession.shared.set(from: tokens)
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
        UserSession.shared.clear()
        HomeStoreCache.clear()
    }
}

private extension String {
    var isExpiredJWT: Bool {
        guard
            let payload = jwtPayload,
            let exp = payload["exp"] as? NSNumber
        else {
            return true
        }

        return Date().timeIntervalSince1970 >= exp.doubleValue
    }

    var jwtPayload: [String: Any]? {
        let parts = split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return json
    }
}
