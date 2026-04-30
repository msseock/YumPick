import SwiftUI

struct OrderView: View {
    @State private var viewModel = OrderViewModel()
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.orders) { order in
                            YPOrderedShopItem(
                                imagePath: order.store.store_image_urls?.first,
                                shopName: order.store.name ?? "",
                                orderCode: order.order_code,
                                paidAt: order.paidAt,
                                menuNames: order.order_menu_list.compactMap { $0.menu.name },
                                totalPrice: Int(order.total_price),
                                reviewRating: order.review?.rating,
                                onDetailTapped: {},
                                onReviewTapped: {}
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await viewModel.fetchOrders()
        }
        .task(id: router.orderReloadToken) {
            await viewModel.fetchOrders()
        }
    }
}
