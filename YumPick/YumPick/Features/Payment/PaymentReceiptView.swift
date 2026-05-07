import SwiftUI

struct PaymentReceiptView: View {
    let orderCode: String
    @State private var viewModel: PaymentReceiptViewModel
    @Environment(\.dismiss) private var dismiss

    init(orderCode: String, client: PaymentClientProtocol = PaymentClient()) {
        self.orderCode = orderCode
        _viewModel = State(initialValue: PaymentReceiptViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("결제 영수증")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") { dismiss() }
                            .foregroundStyle(YPColor.textSecondary)
                    }
                }
        }
        .task {
            await viewModel.load(orderCode: orderCode)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.receipt == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = viewModel.errorMessage, viewModel.receipt == nil {
            errorView(message: message)
        } else if let receipt = viewModel.receipt {
            receiptScrollView(receipt: receipt)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task { await viewModel.load(orderCode: orderCode) }
            }
            .font(YPFont.body2Bold)
            .foregroundStyle(YPColor.actionPrimary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func receiptScrollView(receipt: PaymentReceipt) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard(receipt: receipt)
                paymentMethodCard(receipt: receipt)
                cardInfoCard(receipt: receipt)
                vbankCard(receipt: receipt)
                buyerCard(receipt: receipt)
                timelineCard(receipt: receipt)
                receiptLinkCard(receipt: receipt)
                footerCard(receipt: receipt)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(YPColor.backgroundBrandSubtle)
    }
}

// MARK: - Cards

extension PaymentReceiptView {
    private func headerCard(receipt: PaymentReceipt) -> some View {
        sectionCard("결제 정보") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let name = receipt.name {
                        Text(name)
                            .font(YPFont.body2Bold)
                            .foregroundStyle(YPColor.textPrimary)
                    }
                    Text(formattedAmount(amount: receipt.amount, currency: receipt.currency))
                        .font(YPFont.title1)
                        .foregroundStyle(YPColor.textPrimary)
                }
                Spacer()
                statusBadge(status: receipt.status)
            }
        }
    }

    private func paymentMethodCard(receipt: PaymentReceipt) -> some View {
        let rows: [(String, String?)] = [
            ("결제수단", receipt.pay_method.map { localizedPayMethod($0) }),
            ("결제환경", receipt.channel.map { localizedChannel($0) }),
            ("PG사", receipt.pg_provider),
            ("승인번호", receipt.apply_num),
            ("PG 거래번호", receipt.pg_tid)
        ]
        let hasContent = rows.contains { $0.1 != nil }
        return Group {
            if hasContent {
                sectionCard("결제수단") {
                    ForEach(rows, id: \.0) { label, value in
                        LabeledRow(label: label, value: value)
                    }
                }
            }
        }
    }

    private func cardInfoCard(receipt: PaymentReceipt) -> some View {
        let hasCard = receipt.card_name != nil
        return Group {
            if hasCard {
                sectionCard("카드 정보") {
                    LabeledRow(label: "카드사", value: receipt.card_name)
                    LabeledRow(label: "카드번호", value: receipt.card_number)
                    LabeledRow(label: "할부", value: receipt.card_quota.map { $0 == 0 ? "일시불" : "\($0)개월" })
                }
            }
        }
    }

    private func vbankCard(receipt: PaymentReceipt) -> some View {
        let hasVbank = receipt.vbank_num != nil
        return Group {
            if hasVbank {
                sectionCard("가상계좌") {
                    LabeledRow(label: "은행", value: receipt.vbank_name)
                    LabeledRow(label: "계좌번호", value: receipt.vbank_num)
                    LabeledRow(label: "예금주", value: receipt.vbank_holder)
                    if let epoch = receipt.vbank_date {
                        LabeledRow(label: "입금기한", value: formattedEpoch(epoch))
                    }
                    if let epoch = receipt.vbank_issued_at {
                        LabeledRow(label: "계좌발급", value: formattedEpoch(epoch))
                    }
                }
            }
        }
    }

    private func buyerCard(receipt: PaymentReceipt) -> some View {
        let rows: [(String, String?)] = [
            ("주문자", receipt.buyer_name),
            ("이메일", receipt.buyer_email),
            ("연락처", receipt.buyer_tel),
            ("주소", receipt.buyer_addr)
        ]
        let hasContent = rows.contains { $0.1 != nil }
        return Group {
            if hasContent {
                sectionCard("주문자 정보") {
                    ForEach(rows, id: \.0) { label, value in
                        LabeledRow(label: label, value: value)
                    }
                }
            }
        }
    }

    private func timelineCard(receipt: PaymentReceipt) -> some View {
        let rows: [(String, String?)] = [
            ("결제 요청", receipt.startedAt.map { DateFormatManager.shared.orderDate(from: $0) }),
            ("결제 완료", receipt.paidAt.map { DateFormatManager.shared.orderDate(from: $0) })
        ]
        let hasContent = rows.contains { $0.1 != nil }
        return Group {
            if hasContent {
                sectionCard("결제 시각") {
                    ForEach(rows, id: \.0) { label, value in
                        LabeledRow(label: label, value: value)
                    }
                }
            }
        }
    }

    private func receiptLinkCard(receipt: PaymentReceipt) -> some View {
        Group {
            if let urlString = receipt.receipt_url, let url = URL(string: urlString) {
                sectionCard("매출전표") {
                    Link(destination: url) {
                        HStack {
                            Text("매출전표 보기")
                                .font(YPFont.body2Bold)
                                .foregroundStyle(YPColor.actionPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(YPColor.actionPrimary)
                        }
                    }
                }
            }
        }
    }

    private func footerCard(receipt: PaymentReceipt) -> some View {
        sectionCard("거래 번호") {
            LabeledRow(label: "포트원 번호", value: receipt.imp_uid)
            LabeledRow(label: "주문번호", value: receipt.merchant_uid)
        }
    }
}

// MARK: - Helpers

extension PaymentReceiptView {
    @ViewBuilder
    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textTertiary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusBadge(status: String) -> some View {
        let (label, color) = statusInfo(status)
        return Text(label)
            .font(YPFont.caption1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private func statusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "paid":      return ("결제완료", YPColor.actionPrimary)
        case "ready":     return ("결제대기", YPColor.actionAccent)
        case "cancelled": return ("결제취소", YPColor.semanticDanger)
        case "failed":    return ("결제실패", YPColor.semanticDanger)
        default:          return (status, YPColor.textTertiary)
        }
    }

    private func formattedAmount(amount: Int, currency: String) -> String {
        let formatted = amount.formatted(.number)
        return currency == "KRW" ? "\(formatted)원" : "\(formatted) \(currency)"
    }

    private func formattedEpoch(_ epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        return date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "ko_KR")))
    }

    private func localizedPayMethod(_ method: String) -> String {
        switch method {
        case "card":    return "카드"
        case "trans":   return "계좌이체"
        case "vbank":   return "가상계좌"
        case "phone":   return "휴대폰소액결제"
        case "samsung": return "삼성페이"
        case "kakaopay": return "카카오페이"
        case "naverpay": return "네이버페이"
        default:        return method
        }
    }

    private func localizedChannel(_ channel: String) -> String {
        switch channel {
        case "pc":     return "PC"
        case "mobile": return "모바일"
        default:       return channel
        }
    }
}

// MARK: - LabeledRow

private struct LabeledRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                    .frame(width: 80, alignment: .leading)
                Text(value)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Preview

#Preview("결제완료") {
    PaymentReceiptView(orderCode: "A1234", client: MockPaymentClient())
}

#Preview("에러") {
    let mock = MockPaymentClient()
    mock.fetchReceiptResult = .failure(NetworkError.invalidResponse)
    return PaymentReceiptView(orderCode: "A1234", client: mock)
}
