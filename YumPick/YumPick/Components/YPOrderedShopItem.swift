import SwiftUI

struct YPOrderedShopItem: View {
    var imagePath: String?
    var shopName: String
    var orderCode: String
    var paidAt: String?        // ISO 8601
    var menuNames: [String]    // order_menu_list.compactMap { $0.menu.name }
    var totalPrice: Int
    var reviewRating: Double?  // nil이면 미작성
    var onStoreTapped: () -> Void
    var onReceiptTapped: () -> Void
    var onReviewTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            storeReviewArea
            receiptArea
        }
        .frame(maxWidth: .infinity)
    }

    private var storeReviewArea: some View {
        Button(action: onStoreTapped) {
            HStack(spacing: 12) {
                CachedImage(path: imagePath)
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(shopName)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YP2Color.textPrimary)
                        .lineLimit(1)

                    if let date = formattedDate {
                        Text(date)
                            .font(YPFont.caption1)
                            .foregroundStyle(YP2Color.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onReviewTapped) {
                    reviewButton
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(YP2Color.backgroundPrimary)
            .overlay {
                Rectangle()
                    .stroke(YP2Color.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var reviewButton: some View {
        if let rating = reviewRating {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(YP2Color.actionPrimary)
                Text(ratingText(rating))
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YP2Color.textPrimary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color(hex: "#FFFDF7"))
            .overlay {
                Rectangle()
                    .stroke(YP2Color.ink, lineWidth: 1)
            }
        } else {
            Text("리뷰 작성")
                .font(YPFont.body3Bold)
                .foregroundStyle(YP2Color.paper)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(YP2Color.ink)
                .overlay {
                    Rectangle()
                        .stroke(YP2Color.ink, lineWidth: 1)
                }
        }
    }

    private var receiptArea: some View {
        Button(action: onReceiptTapped) {
            HStack(spacing: 12) {
                Image(systemName: "receipt")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(YP2Color.textPrimary)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(menuSummary)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YP2Color.textPrimary)
                        .lineLimit(1)

                    Text(orderCode)
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text(formattedPrice)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YP2Color.textPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YP2Color.textTertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(YP2Color.backgroundSecondary)
            .overlay {
                Rectangle()
                    .stroke(YP2Color.borderDefault, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String? {
        guard let paidAt else { return nil }
        let date = DateFormatManager.shared.orderDate(from: paidAt)
        return date.isEmpty ? nil : date
    }

    private var menuSummary: String {
        guard let first = menuNames.first else { return "" }
        let remaining = menuNames.count - 1
        return remaining > 0 ? "\(first) 외 \(remaining)개" : first
    }

    private var formattedPrice: String {
        "\(totalPrice.formatted(.number))원"
    }

    private func ratingText(_ rating: Double) -> String {
        let rounded = (rating * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
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
            onStoreTapped: {},
            onReceiptTapped: {},
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
            onStoreTapped: {},
            onReceiptTapped: {},
            onReviewTapped: {}
        )
    }
    .padding()
    .background(YPColor.backgroundBrandSubtle)
}
