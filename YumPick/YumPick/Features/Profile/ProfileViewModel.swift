import Foundation

@Observable
final class ProfileViewModel {
    var isLoading = false
    var errorMessage: String? = nil
    var didLogout = false

    private let client: ProfileClientProtocol

    init(client: ProfileClientProtocol = ProfileClient()) {
        self.client = client
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.logout()
            didLogout = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
