import Foundation
import CoreLocation

@Observable
final class StoreDetailViewModel {

    // MARK: - State

    let storeId: String
    var detail: StoreDetail? = nil
    var isLoading = false
    var errorMessage: String? = nil

    var isLiked = false
    var pickCount = 0

    var searchQuery = ""
    var selectedQuantities: [String: Int] = [:]
    var distanceMeter: Double? = nil

    // MARK: - Dependencies

    private let client: StoreDetailClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        storeId: String,
        client: StoreDetailClientProtocol = StoreDetailClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.storeId = storeId
        self.client = client
        self.locationManager = locationManager
    }

    // MARK: - Derived

    var menuSections: [(category: String, menus: [StoreMenu])] {
        guard let detail else { return [] }
        let grouped = Dictionary(grouping: detail.menu_list) { $0.category ?? "기타" }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (category: $0.key, menus: $0.value) }
    }

    var filteredMenuSections: [(category: String, menus: [StoreMenu])] {
        guard !searchQuery.isEmpty else { return menuSections }
        let q = searchQuery.lowercased()
        return menuSections.compactMap { section in
            let matched = section.menus.filter { $0.name?.lowercased().contains(q) == true }
            return matched.isEmpty ? nil : (category: section.category, menus: matched)
        }
    }

    var totalQuantity: Int {
        selectedQuantities.values.reduce(0, +)
    }

    var totalPrice: Int {
        guard let detail else { return 0 }
        return detail.menu_list.reduce(0) { acc, menu in
            acc + (menu.price ?? 0) * (selectedQuantities[menu.menu_id] ?? 0)
        }
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await client.fetchStoreDetail(storeId: storeId)
            detail = fetched
            isLiked = fetched.is_pick
            pickCount = fetched.pick_count
            await updateDistance(geolocation: fetched.geolocation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike() async {
        let prevLiked = isLiked
        let prevCount = pickCount
        isLiked = !isLiked
        pickCount += isLiked ? 1 : -1
        do {
            let status = try await client.toggleLike(storeId: storeId, likeStatus: isLiked)
            isLiked = status
            pickCount = prevCount + (status ? 1 : -1)
            LikeStateStore.shared.update(storeId: storeId, isLiked: status)
        } catch {
            isLiked = prevLiked
            pickCount = prevCount
        }
    }

    func increase(menuId: String) {
        selectedQuantities[menuId, default: 0] += 1
    }

    func decrease(menuId: String) {
        let current = selectedQuantities[menuId] ?? 0
        if current <= 1 {
            selectedQuantities.removeValue(forKey: menuId)
        } else {
            selectedQuantities[menuId] = current - 1
        }
    }

    func quantity(for menuId: String) -> Int {
        selectedQuantities[menuId] ?? 0
    }

    func makeCheckoutSelection() -> CheckoutSelection? {
        guard let detail, totalQuantity > 0 else { return nil }
        let items = selectedQuantities.compactMap { menuId, quantity -> CheckoutSelectionItem? in
            guard let menu = detail.menu_list.first(where: { $0.menu_id == menuId }) else { return nil }
            return CheckoutSelectionItem(
                menuId: menuId,
                name: menu.name ?? "",
                price: menu.price ?? 0,
                quantity: quantity
            )
        }
        return CheckoutSelection(
            storeId: storeId,
            storeName: detail.name ?? "",
            items: items,
            totalPrice: totalPrice
        )
    }

    // MARK: - Private

    private func updateDistance(geolocation: Geolocation) async {
        guard let currentGeo = await locationManager.currentLocation() else { return }
        let current = CLLocation(latitude: currentGeo.latitude, longitude: currentGeo.longitude)
        let store = CLLocation(latitude: geolocation.latitude, longitude: geolocation.longitude)
        distanceMeter = current.distance(from: store)
    }
}
