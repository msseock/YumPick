import Foundation
import AuthenticationServices

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
            return try await client.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func handleAppleLoginResult(_ result: Result<ASAuthorization, Error>) async -> AuthTokenBundle? {
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
            return await appleLoginTapped(idToken: idToken, deviceToken: nil)
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
