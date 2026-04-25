import Foundation

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
}
