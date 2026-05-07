import Foundation
import AuthenticationServices

struct AppleLoginSession {
    let tokens: AuthTokenBundle
    let appleUserID: String
}

@MainActor
@Observable
final class LoginViewModel {

    // MARK: - State

    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    var canSubmit: Bool { !email.isEmpty && !password.isEmpty }

    // MARK: - Dependency

    private let client: LoginClientProtocol

    init(client: LoginClientProtocol = LoginClient()) {
        self.client = client
    }

    // MARK: - Actions

    func loginTapped() async -> AuthTokenBundle? {
        guard canSubmit else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fcmToken = KeychainManager.shared.read(key: .fcmToken)
            return try await client.login(email: email, password: password, deviceToken: fcmToken)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func handleAppleLoginResult(_ result: Result<ASAuthorization, Error>) async -> AppleLoginSession? {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple 로그인 처리에 실패했습니다."
                return nil
            }
            let fcmToken = KeychainManager.shared.read(key: .fcmToken)
            guard let tokens = await appleLoginTapped(idToken: idToken, deviceToken: fcmToken) else {
                return nil
            }
            return AppleLoginSession(tokens: tokens, appleUserID: credential.user)
        case .failure(let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func appleLoginTapped(idToken: String, deviceToken: String?) async -> AuthTokenBundle? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await client.appleLogin(idToken: idToken, deviceToken: deviceToken)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
