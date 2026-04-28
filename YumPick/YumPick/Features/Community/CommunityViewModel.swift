import Foundation

@Observable
final class CommunityViewModel {
    var posts: [PostSummary] = []
    var isLoading = false
    var errorMessage: String? = nil

    private let client: CommunityClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: CommunityClientProtocol = CommunityClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }
        let geo = await locationManager.currentLocation() ?? Geolocation(longitude: 126.9780, latitude: 37.5665)
        do {
            posts = try await client.fetchPosts(
                longitude: geo.longitude,
                latitude: geo.latitude,
                category: nil,
                orderBy: "createdAt"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
