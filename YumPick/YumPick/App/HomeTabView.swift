import SwiftUI

enum HomePath: Hashable {
    case storeDetail(storeId: String)
    case orderConfirm(selection: CheckoutSelection)
    case paymentComplete(orderCode: String, totalPrice: Int, impUid: String)
}

struct HomeTabView: View {
    @Binding var path: [HomePath]
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: HomePath.self) { destination in
                    switch destination {
                    case .storeDetail(let storeId):
                        StoreDetailView(storeId: storeId)
                    case .orderConfirm(let selection):
                        OrderConfirmView(selection: selection) { orderCode, totalPrice, impUid in
                            path.append(.paymentComplete(
                                orderCode: orderCode,
                                totalPrice: totalPrice,
                                impUid: impUid
                            ))
                        }
                    case .paymentComplete(let orderCode, let totalPrice, let impUid):
                        PaymentCompleteView(
                            orderCode: orderCode,
                            totalPrice: totalPrice,
                            impUid: impUid
                        ) {
                            router.homePath.removeAll()
                            router.selectedTab = .order
                            router.bumpOrderReload()
                        }
                    }
                }
        }
    }
}
