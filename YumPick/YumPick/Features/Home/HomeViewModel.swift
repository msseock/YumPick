import Foundation

private let seoulCityHall = Geolocation(longitude: 126.9780, latitude: 37.5665)

@Observable
final class HomeViewModel {
    var banners: [Banner] = []
    var popularStores: [StoreSummary] = []
    var popularSearches: [String] = []
    var nearbyStores: [StoreSummary] = []
    var isLoading = false
    var errorMessage: String? = nil

    private let client: HomeClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: HomeClientProtocol = HomeClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func fetchContent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let banners = client.fetchBanners()
            async let popularStores = client.fetchPopularStores(category: nil)
            async let popularSearches = client.fetchPopularSearches()
            self.banners = try await banners
            self.popularStores = try await popularStores
            self.popularSearches = try await popularSearches
        } catch {
            errorMessage = error.localizedDescription
        }
        await fetchNearbyStores()
    }

    private func fetchNearbyStores() async {
        let geo = await locationManager.currentLocation() ?? seoulCityHall
        do {
            nearbyStores = try await client.fetchNearbyStores(
                longitude: geo.longitude,
                latitude: geo.latitude,
                orderBy: "distance"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
