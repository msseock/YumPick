import Foundation

@Observable
final class CommunityStorePickerViewModel {
    var stores: [StoreSummary] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String? = nil

    private let client: HomeClientProtocol
    private let locationManager: any LocationManagerProtocol
    private let seoulCityHall = Geolocation(longitude: 126.9780, latitude: 37.5665)

    init(
        client: HomeClientProtocol = HomeClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    var filteredStores: [StoreSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return stores }

        return stores.filter { store in
            store.name?.localizedCaseInsensitiveContains(query) == true ||
            store.category?.localizedCaseInsensitiveContains(query) == true ||
            store.hashTags?.contains(where: { $0.localizedCaseInsensitiveContains(query) }) == true
        }
    }

    func loadStoresIfNeeded() async {
        guard stores.isEmpty else { return }
        await refreshStores()
    }

    func refreshStores() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let geo = await locationManager.currentLocation() ?? seoulCityHall

        do {
            let page = try await client.fetchNearbyStores(
                longitude: geo.longitude,
                latitude: geo.latitude,
                orderBy: "distance",
                category: nil,
                next: nil
            )
            stores = page.stores
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
