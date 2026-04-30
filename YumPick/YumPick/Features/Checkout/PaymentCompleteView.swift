import SwiftUI

struct PaymentCompleteView: View {
    @State private var viewModel: PaymentCompleteViewModel
    // TODO: coordinator 패턴 도입 시 AppRouter로 전환
    let onGoToOrders: () -> Void

    init(
        orderCode: String,
        totalPrice: Int,
        impUid: String,
        onGoToOrders: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: PaymentCompleteViewModel(
            orderCode: orderCode,
            totalPrice: totalPrice
        ))
        self.onGoToOrders = onGoToOrders
        self._impUid = State(initialValue: impUid)
    }

    @State private var impUid: String

    var body: some View {
        Group {
            switch viewModel.phase {
            case .validating:
                validatingView
            case .success:
                successView
            case .failure:
                failureView
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.validate(impUid: impUid) }
    }

    // MARK: - Validating

    private var validatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("결제 확인 중...")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(YPColor.brandDeepSprout)
                .padding(.bottom, 20)

            Text("결제가 완료되었어요")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                infoRow(label: "주문번호", value: viewModel.orderCode)
                infoRow(label: "결제금액", value: "\(viewModel.totalPrice.formatted())원")
            }
            .padding(16)
            .background(YPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            Button {
                onGoToOrders()
            } label: {
                Text("주문 내역으로")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(YPColor.brandBlackSprout)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Failure

    private var failureView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(YPColor.textTertiary)
                .padding(.bottom, 20)

            Text("결제 확인에 실패했어요")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.bottom, 8)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                onGoToOrders()
            } label: {
                Text("닫기")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(YPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
            Spacer()
            Text(value)
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        PaymentCompleteView(
            orderCode: "ORDER-20240501-001",
            totalPrice: 10000,
            impUid: "imp_mock_uid",
            onGoToOrders: {}
        )
    }
}
