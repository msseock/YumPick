import Foundation

private let seoulCityHall = Geolocation(longitude: 126.9780, latitude: 37.5665)

@Observable
final class PickViewModel {
    var stores: [StoreSummary] = []
    var isLoading = false
    var errorMessage: String? = nil

    private let client: PickClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: PickClientProtocol = PickClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func fetchStores() async {
        isLoading = true
        defer { isLoading = false }
        let geo = await locationManager.currentLocation() ?? seoulCityHall
        do {
            stores = try await client.fetchNearbyStores(
                longitude: geo.longitude,
                latitude: geo.latitude,
                orderBy: "distance"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
