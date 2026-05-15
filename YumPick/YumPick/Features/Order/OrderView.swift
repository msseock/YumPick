import SwiftUI

struct OrderView: View {
    @State private var viewModel = OrderViewModel()
    @Environment(AppRouter.self) private var router
    @State private var reviewTarget: Order? = nil
    @State private var receiptTarget: Order? = nil
    @State private var showErrorAlert = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage, viewModel.orders.isEmpty {
                fetchErrorView(message: message)
            } else if viewModel.orders.isEmpty {
                OrderEmptyView()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        PickupNoticeBanner()
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 16)

                        CurrentOrderSection(order: viewModel.orders[0]) {
                            Task { await viewModel.advanceStatus(of: viewModel.orders[0]) }
                        }
                        .allowsHitTesting(!viewModel.isUpdatingStatus)

                        if viewModel.orders.count > 1 {
                            PastOrderSection(orders: Array(viewModel.orders.dropFirst())) { order in
                                openStoreDetail(for: order)
                            } onReceiptTapped: { order in
                                receiptTarget = order
                            } onReviewTapped: { order in
                                reviewTarget = order
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
                .refreshable {
                    await viewModel.fetchOrders()
                }
                .background(YP2Color.backgroundPrimary)
            }
        }
        .task {
            await viewModel.fetchOrders()
        }
        .task(id: router.orderReloadToken) {
            await viewModel.fetchOrders()
        }
        .onChange(of: viewModel.errorMessage) { _, new in
            if new != nil && !viewModel.orders.isEmpty {
                showErrorAlert = true
            }
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .sheet(item: $reviewTarget) { order in
            reviewSheet(for: order)
        }
        .sheet(item: $receiptTarget) { order in
            PaymentReceiptView(orderCode: order.order_code)
        }
    }

    @ViewBuilder
    private func fetchErrorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task { await viewModel.fetchOrders() }
            }
            .font(YPFont.body2Bold)
            .foregroundStyle(YPColor.actionPrimary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func openStoreDetail(for order: Order) {
        guard let storeId = order.store.id else { return }
        router.homePath.append(.storeDetail(storeId: storeId))
        router.selectedTab = .home
    }
}

// MARK: - Pickup Notice Banner

private struct PickupNoticeBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "megaphone")
                .font(.system(size: 14, weight: .bold))
            Text("픽업 시 주문번호를 보여주세요")
                .font(YPFont.body3Bold)
            Spacer()
        }
        .foregroundStyle(YP2Color.textPrimary)
        .padding(13)
        .background(YP2Color.actionPrimary)
        .overlay {
            Rectangle()
                .stroke(YP2Color.ink, lineWidth: 1)
        }
    }
}

// MARK: - Current Order Section

private struct CurrentOrderSection: View {
    let order: Order
    var onStatusAdvance: (() -> Void)? = nil

    private static let activeStatuses: Set<String> = [
        "PENDING_APPROVAL", "APPROVED", "IN_PROGRESS", "READY_FOR_PICKUP"
    ]

    private var isActiveOrder: Bool {
        Self.activeStatuses.contains(order.current_order_status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("주문현황")
                .font(YPFont.title1)
                .foregroundStyle(YP2Color.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                if isActiveOrder {
                    YPOrderProgressCard(
                        orderCode: order.order_code,
                        shopName: order.store.name ?? "",
                        paidAt: order.paidAt,
                        storeImagePath: order.store.store_image_urls?.first,
                        timeline: order.order_status_timeline
                    )
                    #if DEBUG
                    .onTapGesture { onStatusAdvance?() }
                    #endif
                } else {
                    OrderTerminalCard(
                        orderCode: order.order_code,
                        shopName: order.store.name ?? "",
                        paidAt: order.paidAt,
                        storeImagePath: order.store.store_image_urls?.first,
                        status: order.current_order_status
                    )
                }

                YP2Color.backgroundSecondary
                    .frame(height: 8)

                OrderMenuListCard(order: order)
            }
            .background {
                Rectangle()
                    .fill(YP2Color.backgroundPrimary)
                    .shadow(color: YP2Color.ink.opacity(0.08), radius: 6, x: 0, y: 4)
            }
            .overlay {
                Rectangle()
                    .stroke(YP2Color.ink, lineWidth: 1)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(YP2Color.backgroundPrimary)
    }
}

// MARK: - Order Terminal Card

private struct OrderTerminalCard: View {
    let orderCode: String
    let shopName: String
    let paidAt: String?
    let storeImagePath: String?
    let status: String

    private var statusInfo: (label: String, color: Color) {
        switch status {
        case "PICKED_UP":  return ("픽업완료", YP2Color.accentGreen)
        case "CANCELED":   return ("주문취소", YPColor.semanticDanger)
        case "REFUNDED":   return ("환불완료", YP2Color.textTertiary)
        case "FAILED":     return ("결제실패", YPColor.semanticDanger)
        default:           return (status,    YP2Color.textTertiary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("주문번호")
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.textTertiary)
                    Text(orderCode)
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YP2Color.textSecondary)
                }

                Text(shopName)
                    .font(YPFont.title1)
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(2)

                Text(paidAt.map { DateFormatManager.shared.orderDate(from: $0) } ?? "")
                    .font(YPFont.caption2)
                    .foregroundStyle(YP2Color.textTertiary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack {
                Text(statusInfo.label)
                    .font(YPFont.body2Bold)
                    .foregroundStyle(statusInfo.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusInfo.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(YP2Color.backgroundPrimary)
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
                    .foregroundStyle(YP2Color.textTertiary)

                Spacer()

                Text("\(totalQuantity)EA")
                    .font(YPFont.caption1)
                    .foregroundStyle(YP2Color.textTertiary)
                    .padding(.trailing, 8)

                Text("\(Int(order.total_price).formatted())원")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YP2Color.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(YP2Color.backgroundPrimary)
    }
}

// MARK: - Past Order Section

private struct PastOrderSection: View {
    let orders: [Order]
    var onStoreTapped: (Order) -> Void
    var onReceiptTapped: (Order) -> Void
    var onReviewTapped: (Order) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("이전 주문")
                    .font(YPFont.title1)
                    .foregroundStyle(YP2Color.textPrimary)

                Spacer()

                Text("\(orders.count)건")
                    .font(YPFont.caption1)
                    .foregroundStyle(YP2Color.textTertiary)
            }
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
                        onStoreTapped: { onStoreTapped(order) },
                        onReceiptTapped: { onReceiptTapped(order) },
                        onReviewTapped: { onReviewTapped(order) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 18)
        .padding(.bottom, 24)
    }
}
