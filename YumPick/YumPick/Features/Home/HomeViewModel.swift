import Foundation

@Observable
final class HomeViewModel {
    var isLoading = false
    var errorMessage: String? = nil

    private let client: HomeClientProtocol

    init(client: HomeClientProtocol = HomeClient()) {
        self.client = client
    }

    func fetchContent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.fetchContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
