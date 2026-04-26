import Foundation

@Observable
final class PickViewModel {
    var isLoading = false
    var errorMessage: String? = nil

    private let client: PickClientProtocol

    init(client: PickClientProtocol = PickClient()) {
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
