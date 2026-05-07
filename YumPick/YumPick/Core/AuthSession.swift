import AuthenticationServices
import Foundation

enum LoginProvider: String {
    case email
    case apple
}

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
        case logoutRequired
    }

    var state: State = .checking
    private(set) var userID: String?
    private(set) var nick: String?
    private(set) var sessionMessage: String?
    private(set) var isCompletingRequiredLogout = false

    var needsAppleCredentialValidation: Bool {
        state == .authenticated
            && keychain.read(key: .loginProvider) == LoginProvider.apple.rawValue
            && keychain.read(key: .appleUserID) != nil
    }

    private let keychain: KeychainManager
    private let loginClient: LoginClientProtocol

    init(
        keychain: KeychainManager? = nil,
        loginClient: LoginClientProtocol? = nil
    ) {
        self.keychain = keychain ?? .shared
        self.loginClient = loginClient ?? LoginClient()
    }

    func restore() async {
        if isLogoutRequired {
            restoreCachedUser()
            state = .logoutRequired
            return
        }

        let accessToken = keychain.read(key: .accessToken)
        let refreshToken = keychain.read(key: .refreshToken)
        restoreCachedUser()

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

    func login(
        tokens: AuthTokenBundle,
        provider: LoginProvider = .email,
        appleUserID: String? = nil
    ) {
        keychain.save(key: .accessToken, value: tokens.accessToken)
        keychain.save(key: .refreshToken, value: tokens.refreshToken)
        keychain.save(key: .userID, value: tokens.userID)
        keychain.save(key: .nick, value: tokens.nick)
        keychain.save(key: .loginProvider, value: provider.rawValue)
        keychain.delete(key: .logoutRequired)

        if provider == .apple, let appleUserID {
            keychain.save(key: .appleUserID, value: appleUserID)
        } else {
            keychain.delete(key: .appleUserID)
        }

        self.userID = tokens.userID
        self.nick = tokens.nick
        sessionMessage = nil
        UserSession.shared.set(from: tokens)
        state = .authenticated
    }

    func updateCurrentUser(nick: String, profileImage: String?) {
        keychain.save(key: .nick, value: nick)
        self.nick = nick
        UserSession.shared.nick = nick
        UserSession.shared.profileImage = profileImage
    }

    func logout() {
        clearTokens()
        state = .unauthenticated
    }

    func expire() {
        clearTokens()
        state = .expired
    }

    func validateAppleCredentialIfNeeded(isNetworkConnected: Bool) async {
        guard needsAppleCredentialValidation,
              let appleUserID = keychain.read(key: .appleUserID)
        else {
            return
        }

        let credentialState = await appleCredentialState(for: appleUserID)
        switch credentialState {
        case .authorized:
            return
        case .revoked, .notFound, .transferred:
            markLogoutRequired(message: "Apple 로그인 사용이 중단되어 다시 로그인해주세요.")
            if isNetworkConnected {
                await completeRequiredLogoutIfPossible()
            }
        @unknown default:
            return
        }
    }

    func completeRequiredLogoutIfPossible() async {
        guard isLogoutRequired, !isCompletingRequiredLogout else { return }
        isCompletingRequiredLogout = true
        defer { isCompletingRequiredLogout = false }

        do {
            try await loginClient.logout()
            clearTokens()
            state = .unauthenticated
        } catch {
            if error.isConnectivityFailure {
                state = .logoutRequired
            } else {
                clearTokens()
                state = .expired
            }
        }
    }

    private func clearTokens() {
        keychain.delete(key: .accessToken)
        keychain.delete(key: .refreshToken)
        keychain.delete(key: .userID)
        keychain.delete(key: .nick)
        keychain.delete(key: .loginProvider)
        keychain.delete(key: .appleUserID)
        keychain.delete(key: .logoutRequired)
        self.userID = nil
        self.nick = nil
        sessionMessage = nil
        UserSession.shared.clear()
        HomeStoreCache.clear()
    }

    private var isLogoutRequired: Bool {
        keychain.read(key: .logoutRequired) == "true"
    }

    private func restoreCachedUser() {
        self.userID = keychain.read(key: .userID)
        self.nick = keychain.read(key: .nick)
    }

    private func markLogoutRequired(message: String) {
        keychain.save(key: .logoutRequired, value: "true")
        sessionMessage = message
        state = .logoutRequired
    }

    private func appleCredentialState(
        for appleUserID: String
    ) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, _ in
                continuation.resume(returning: state)
            }
        }
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

private extension Error {
    var isConnectivityFailure: Bool {
        guard let urlError = self as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .timedOut,
             .dataNotAllowed,
             .internationalRoamingOff:
            return true
        default:
            return false
        }
    }
}
