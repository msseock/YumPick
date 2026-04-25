import Foundation

@Observable
final class JoinViewModel {

    // MARK: - State

    var email = ""
    var password = ""
    var passwordConfirm = ""
    var nick = ""

    enum EmailCheckState { case idle, loading, available, duplicated, invalid }
    var emailCheckState: EmailCheckState = .idle

    var isLoading = false
    var errorMessage: String?
    var joinTokens: AuthTokenBundle?

    // MARK: - Validation errors (per-field)

    var emailError: String? {
        guard !email.isEmpty else { return nil }
        return isValidEmailFormat(email) ? nil : "올바른 이메일 형식이 아닙니다"
    }

    var passwordError: String? {
        guard !password.isEmpty else { return nil }
        return isValidPassword(password) ? nil : "8자 이상, 영문·숫자·특수문자(@$!%*#?&) 각 1개 이상 포함"
    }

    var passwordConfirmError: String? {
        guard !passwordConfirm.isEmpty else { return nil }
        return password == passwordConfirm ? nil : "비밀번호가 일치하지 않습니다"
    }

    var nickError: String? {
        guard !nick.isEmpty else { return nil }
        return isValidNick(nick) ? nil : "사용할 수 없는 닉네임입니다"
    }

    var canCheckEmail: Bool { !email.isEmpty && isValidEmailFormat(email) }

    var canSubmit: Bool {
        emailCheckState == .available &&
        passwordError == nil && !password.isEmpty &&
        passwordConfirmError == nil && !passwordConfirm.isEmpty &&
        nickError == nil && !nick.isEmpty
    }

    // MARK: - Dependency

    private let client: JoinClientProtocol

    init(client: JoinClientProtocol = JoinClient()) {
        self.client = client
    }

    // MARK: - Actions

    func checkEmailTapped() async {
        guard canCheckEmail else { return }
        emailCheckState = .loading
        do {
            try await client.validateEmail(email)
            emailCheckState = .available
        } catch NetworkError.clientError(409) {
            emailCheckState = .duplicated
        } catch {
            emailCheckState = .invalid
        }
    }

    func submitTapped() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            joinTokens = try await client.join(email: email, password: password, nick: nick)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private validation

    private func isValidEmailFormat(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func isValidPassword(_ password: String) -> Bool {
        let regex = #"^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$"#
        return password.range(of: regex, options: .regularExpression) != nil
    }

    private func isValidNick(_ nick: String) -> Bool {
        let forbidden = #"[-.,?*@+^${}()|[\]\\]"#
        return nick.range(of: forbidden, options: .regularExpression) == nil
    }
}
