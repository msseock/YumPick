import SwiftUI
import iamport_ios
internal import Then

struct OrderConfirmView: View {
    @State private var viewModel: OrderConfirmViewModel
    // TODO: coordinator 패턴 도입 시 path 직접 push로 전환
    let onPaymentSuccess: (_ orderCode: String, _ totalPrice: Int, _ impUid: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showPayment = false
    @State private var showSoldOutAlert = false
    @State private var showErrorAlert = false
    @State private var paymentErrorMessage: String? = nil

    init(
        selection: CheckoutSelection,
        onPaymentSuccess: @escaping (_ orderCode: String, _ totalPrice: Int, _ impUid: String) -> Void
    ) {
        _viewModel = State(initialValue: OrderConfirmViewModel(selection: selection))
        self.onPaymentSuccess = onPaymentSuccess
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    menuListSection
                    totalSection
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 80)
                }
            }
            bottomBar
        }
        .navigationTitle("주문 확인")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .paying { showPayment = true }
            if phase == .idle && !viewModel.soldOutMenuNames.isEmpty { showSoldOutAlert = true }
            if phase == .error { showErrorAlert = true }
        }
        .fullScreenCover(isPresented: $showPayment) {
            if let order = viewModel.createdOrder {
                let payment = IamportPayment(
                    pg: PG.html5_inicis.makePgRawName(pgId: "INIpayTest"),
                    merchant_uid: order.order_code,
                    amount: "\(order.total_price)"
                ).then {
                    $0.pay_method = PayMethod.card.rawValue
                    $0.name = viewModel.selection.storeName
                    $0.buyer_name = "석민솔"
                    $0.app_scheme = "yumpick"
                }
                IamportPaymentView(payment: payment) { response in
                    showPayment = false
                    if response?.success == true, let impUid = response?.imp_uid {
                        onPaymentSuccess(
                            order.order_code,
                            order.total_price,
                            impUid
                        )
                    } else {
                        paymentErrorMessage = response?.error_msg ?? "결제에 실패했습니다."
                        showErrorAlert = true
                    }
                }
            }
        }
        .alert("품절 메뉴 안내", isPresented: $showSoldOutAlert) {
            Button("닫기") {
                viewModel.soldOutMenuNames = []
                dismiss()
            }
        } message: {
            Text("\(viewModel.soldOutMenuNames.joined(separator: ", "))이(가) 품절되었습니다.\n메뉴를 다시 선택해주세요.")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인") {
                viewModel.phase = .idle
                paymentErrorMessage = nil
            }
        } message: {
            Text(paymentErrorMessage ?? viewModel.errorMessage ?? "오류가 발생했습니다.")
        }
    }

    // MARK: - Menu List

    private var menuListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.selection.storeName)
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

            YPDivider()

            ForEach(viewModel.selection.items, id: \.menuId) { item in
                menuRow(item: item)
                YPDivider().padding(.leading, 16)
            }
        }
    }

    private func menuRow(item: CheckoutSelectionItem) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(item.name)
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantity)개")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textSecondary)
                Text("\(item.subtotal.formatted())원")
                    .font(YPFont.body2Bold)
                    .foregroundStyle(YPColor.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Total

    private var totalSection: some View {
        HStack {
            Text("총 결제금액")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
            Spacer()
            Text("\(viewModel.selection.totalPrice.formatted())원")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        let isProcessing = viewModel.phase == .checkingStock || viewModel.phase == .creatingOrder
        return Button {
            Task { await viewModel.startCheckout() }
        } label: {
            Group {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("결제하기")
                        .font(YPFont.body1Bold)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isProcessing ? YPColor.textTertiary : YPColor.brandBlackSprout)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isProcessing)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .top) { Divider() }
    }
}

#Preview {
    NavigationStack {
        OrderConfirmView(
            selection: CheckoutSelection(
                storeId: "mock-store-id",
                storeName: "새싹 도넛 가게",
                items: [
                    CheckoutSelectionItem(menuId: "1", name: "올리브 그린 새싹 도넛", price: 3200, quantity: 2),
                    CheckoutSelectionItem(menuId: "2", name: "레몬 민트 새싹 도넛", price: 3600, quantity: 1)
                ],
                totalPrice: 10000
            ),
            onPaymentSuccess: { _, _, _ in }
        )
    }
}
