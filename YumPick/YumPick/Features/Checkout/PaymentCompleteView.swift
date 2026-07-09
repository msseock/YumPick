import SwiftUI

struct PaymentCompleteView: View {
    @State private var viewModel: PaymentCompleteViewModel
    // TODO: coordinator 패턴 도입 시 AppRouter로 전환
    let onGoToOrders: () -> Void
    private let skipValidation: Bool

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
        self.skipValidation = false
    }

    /// 미리보기 등 검증 단계를 건너뛰고 특정 phase를 바로 보여줄 때 사용한다.
    init(
        viewModel: PaymentCompleteViewModel,
        onGoToOrders: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onGoToOrders = onGoToOrders
        self._impUid = State(initialValue: "")
        self.skipValidation = true
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
        .task {
            guard !skipValidation else { return }
            await viewModel.validate(impUid: impUid)
        }
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
                .foregroundStyle(YP2Color.actionPrimary)
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            Button {
                onGoToOrders()
            } label: {
                Text("주문 내역으로")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(YP2Color.actionPrimary)
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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

#Preview("결제 성공") {
    let viewModel = PaymentCompleteViewModel(
        orderCode: "ORDER-20240501-001",
        totalPrice: 10000
    )
    viewModel.phase = .success

    return NavigationStack {
        PaymentCompleteView(viewModel: viewModel, onGoToOrders: {})
    }
}

#Preview("결제 실패") {
    let viewModel = PaymentCompleteViewModel(
        orderCode: "ORDER-20240501-001",
        totalPrice: 10000
    )
    viewModel.phase = .failure
    viewModel.errorMessage = "결제 정보를 확인할 수 없습니다. 잠시 후 다시 시도해주세요."

    return NavigationStack {
        PaymentCompleteView(viewModel: viewModel, onGoToOrders: {})
    }
}

#Preview("결제 확인 중") {
    let viewModel = PaymentCompleteViewModel(
        orderCode: "ORDER-20240501-001",
        totalPrice: 10000
    )
    viewModel.phase = .validating

    return NavigationStack {
        PaymentCompleteView(viewModel: viewModel, onGoToOrders: {})
    }
}
