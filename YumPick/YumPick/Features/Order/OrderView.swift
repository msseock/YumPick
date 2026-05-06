import SwiftUI

struct OrderView: View {
    @State private var viewModel = OrderViewModel()
    @Environment(AppRouter.self) private var router
    @State private var reviewTarget: Order? = nil

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.orders.isEmpty {
                OrderEmptyView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        PickupNoticeBanner()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)

                        CurrentOrderSection(order: viewModel.orders[0]) {
                            Task { await viewModel.advanceStatus(of: viewModel.orders[0]) }
                        }
                        .allowsHitTesting(!viewModel.isUpdatingStatus)

                        if viewModel.orders.count > 1 {
                            PastOrderSection(orders: Array(viewModel.orders.dropFirst())) { order in
                                reviewTarget = order
                            }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.fetchOrders()
        }
        .task(id: router.orderReloadToken) {
            await viewModel.fetchOrders()
        }
        .sheet(item: $reviewTarget) { order in
            reviewSheet(for: order)
        }
    }

    @ViewBuilder
    private func reviewSheet(for order: Order) -> some View {
        if let storeId = order.store.id {
            if let review = order.review {
                WriteReviewView(mode: .edit(storeId: storeId, reviewId: review.id)) {
                    Task { await viewModel.fetchOrders() }
                }
            } else {
                WriteReviewView(mode: .create(storeId: storeId, orderCode: order.order_code)) {
                    Task { await viewModel.fetchOrders() }
                }
            }
        }
    }
}

// MARK: - Pickup Notice Banner

private struct PickupNoticeBanner: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("픽업").font(YPFont.body2).foregroundStyle(YPColor.textPrimary)
            Text("을 하실 때는 ").font(YPFont.body2).foregroundStyle(YPColor.brandDeepSprout)
            Text("주문번호").font(YPFont.body2).foregroundStyle(YPColor.textPrimary)
            Text("를 꼭 말씀해주세요!").font(YPFont.body2).foregroundStyle(YPColor.brandDeepSprout)
            Spacer()
        }
        .padding(.vertical, 9)
        .background(YPColor.brandBrightSprout)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(
            color: Color(red: 82/255, green: 81/255, blue: 86/255).opacity(0.2),
            radius: 10.5, x: 0, y: 4
        )
    }
}

// MARK: - Current Order Section

private struct CurrentOrderSection: View {
    let order: Order
    var onStatusAdvance: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("주문현황")
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textTertiary)
                .padding(.horizontal, 20)

            YPOrderProgressCard(
                orderCode: order.order_code,
                shopName: order.store.name ?? "",
                paidAt: order.paidAt,
                storeImagePath: order.store.store_image_urls?.first,
                timeline: order.order_status_timeline
            )
            .padding(.horizontal, 20)
            .onTapGesture { onStatusAdvance?() }

            OrderMenuListCard(order: order)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(YPColor.backgroundSecondary)
        .overlay(alignment: .top) {
            Divider().foregroundStyle(YPColor.borderSubtle)
        }
        .overlay(alignment: .bottom) {
            Divider().foregroundStyle(YPColor.borderSubtle)
        }
    }
}

// MARK: - Order Menu List Card

private struct OrderMenuListCard: View {
    let order: Order

    private var totalQuantity: Int {
        order.order_menu_list.reduce(0) { $0 + Int($1.quantity) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(order.order_menu_list.enumerated()), id: \.offset) { index, item in
                YPOrderMenuRow(
                    imagePath: item.menu.menu_image_url,
                    name: item.menu.name ?? "",
                    price: item.menu.price ?? 0,
                    quantity: Int(item.quantity)
                )
                .padding(.vertical, 12)

                if index < order.order_menu_list.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            Divider()
                .padding(.horizontal, 16)

            HStack {
                Text("결제금액")
                    .font(YPFont.body2Bold)
                    .foregroundStyle(YPColor.textTertiary)

                Spacer()

                Text("\(totalQuantity)EA")
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                    .padding(.trailing, 8)

                Text("\(Int(order.total_price).formatted())원")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color(red: 123/255, green: 120/255, blue: 134/255).opacity(0.08),
            radius: 6, x: 0, y: 4
        )
    }
}

// MARK: - Past Order Section

private struct PastOrderSection: View {
    let orders: [Order]
    var onReviewTapped: (Order) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이전주문 내역")
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textTertiary)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(orders) { order in
                    YPOrderedShopItem(
                        imagePath: order.store.store_image_urls?.first,
                        shopName: order.store.name ?? "",
                        orderCode: order.order_code,
                        paidAt: order.paidAt,
                        menuNames: order.order_menu_list.compactMap { $0.menu.name },
                        totalPrice: Int(order.total_price),
                        reviewRating: order.review?.rating,
                        onDetailTapped: {},
                        onReviewTapped: { onReviewTapped(order) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
}
