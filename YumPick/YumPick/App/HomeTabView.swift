import SwiftUI

enum HomePath: Hashable {
    case storeDetail(storeId: String)
}

struct HomeTabView: View {
    @Binding var path: [HomePath]

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: HomePath.self) { destination in
                    switch destination {
                    case .storeDetail(let storeId):
                        StoreDetailView(storeId: storeId)
                    }
                }
        }
    }
}
