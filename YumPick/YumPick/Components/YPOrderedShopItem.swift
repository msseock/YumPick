import SwiftUI

struct YPOrderedShopItem: View {
    var imagePath: String?
    var shopName: String
    var orderCode: String
    var paidAt: String         // ISO 8601
    var menuNames: [String]    // order_menu_list.compactMap { $0.menu.name }
    var totalPrice: Int
    var reviewRating: Double?  // nil이면 미작성
    var onDetailTapped: () -> Void
    var onReviewTapped: () -> Void

    private var reviewState: YPReviewButtonState {
        reviewRating.map { .reviewed(rating: $0) } ?? .default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                orderInfoView
                Spacer()
                CachedImage(path: imagePath)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            YPReviewButton(state: reviewState, action: onReviewTapped)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color(red: 123/255, green: 120/255, blue: 134/255).opacity(0.08),
            radius: 6, x: 0, y: 4
        )
    }

    private var orderInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shopName)
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textSecondary)
                .lineLimit(1)

            orderMetaRow
            orderSummaryRow
        }
    }

    private var orderMetaRow: some View {
        HStack(spacing: 12) {
            Text(orderCode)
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)

            Text(DateFormatManager.orderDate(from: paidAt))
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.borderDefault)
        }
    }

    private var orderSummaryRow: some View {
        Button(action: onDetailTapped) {
            HStack(spacing: 12) {
                Text(menuSummary)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textTertiary)

                HStack(spacing: 0) {
                    Text(formattedPrice)
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YPColor.actionPrimary)

                    Image("chevron")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(YPColor.actionPrimary)
                        .frame(width: 16, height: 16)
                        .scaleEffect(x: -1, y: 1) // 좌우 반전 핵심 코드
                        .fontWeight(.medium)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var menuSummary: String {
        guard let first = menuNames.first else { return "" }
        let remaining = menuNames.count - 1
        return remaining > 0 ? "\(first) 외 \(remaining)건" : first
    }

    private var formattedPrice: String {
        let formatted = totalPrice.formatted(.number)
        return "\(formatted)원"
    }
}

#Preview {
    VStack(spacing: 16) {
        YPOrderedShopItem(
            imagePath: nil,
            shopName: "새싹 도넛 가게",
            orderCode: "A1234",
            paidAt: "2025-04-26T15:00:00.000Z",
            menuNames: ["크림 도넛", "초코 도넛", "딸기 도넛"],
            totalPrice: 10000,
            reviewRating: nil,
            onDetailTapped: {},
            onReviewTapped: {}
        )

        YPOrderedShopItem(
            imagePath: nil,
            shopName: "새싹 도넛 가게",
            orderCode: "A5678",
            paidAt: "2025-04-26T15:00:00.000Z",
            menuNames: ["크림 도넛"],
            totalPrice: 32500,
            reviewRating: 4.5,
            onDetailTapped: {},
            onReviewTapped: {}
        )
    }
    .padding()
    .background(YPColor.backgroundBrandSubtle)
}
