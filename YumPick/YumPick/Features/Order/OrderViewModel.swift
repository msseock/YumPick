import Foundation

@Observable
final class OrderViewModel {
    var isLoading = false
    var errorMessage: String? = nil

    private let client: OrderClientProtocol

    init(client: OrderClientProtocol = OrderClient()) {
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
