import SwiftUI

struct PickView: View {
    @State private var viewModel = PickViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.stores.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.stores) { store in
                            YPPopularShopCard(
                                imagePath: store.store_image_urls?.first,
                                shopName: store.name ?? "",
                                pickupCount: store.pick_count ?? 0,
                                distance: store.distance.map { String(format: "%.0fm", $0) } ?? "",
                                closeTime: store.close ?? "",
                                visitCount: store.total_order_count ?? 0,
                                isLiked: store.is_pick ?? false,
                                isPickchelin: store.is_picchelin ?? false,
                                onLikeTapped: {}
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await viewModel.fetchStores()
        }
    }
}
