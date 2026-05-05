import Foundation

@Observable
final class CommunitySearchViewModel {
    var query: String = ""
    var results: [PostSummary] = []
    var isLoading = false
    var errorMessage: String? = nil

    private var searchTask: Task<Void, Never>? = nil
    private let client: CommunityClientProtocol

    init(client: CommunityClientProtocol = CommunityClient()) {
        self.client = client
    }

    func onQueryChanged(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()

        guard !newQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await search(query: newQuery)
        }
    }

    private func search(query: String) async {
        defer { isLoading = false }
        do {
            results = try await client.searchPosts(title: query)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }
}
