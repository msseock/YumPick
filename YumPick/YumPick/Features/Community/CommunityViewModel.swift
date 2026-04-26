import Foundation

@Observable
final class CommunityViewModel {
    var isLoading = false
    var errorMessage: String? = nil

    private let client: CommunityClientProtocol

    init(client: CommunityClientProtocol = CommunityClient()) {
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
