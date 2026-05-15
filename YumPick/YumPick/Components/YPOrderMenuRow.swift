import SwiftUI

struct YPOrderMenuRow: View {
    var imagePath: String?
    var name: String
    var price: Int
    var quantity: Int

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(path: imagePath)
                .frame(width: 84, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(YPFont.body2Bold)
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(1)

                Text("\(price.formatted())원    \(quantity)EA")
                    .font(YPFont.body2)
                    .foregroundStyle(YP2Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 12) {
        YPOrderMenuRow(
            imagePath: nil,
            name: "올리브 그린 새싹 도넛",
            price: 3200,
            quantity: 2
        )
        YPOrderMenuRow(
            imagePath: nil,
            name: "레몬 민트 새싹 도넛",
            price: 3600,
            quantity: 3
        )
    }
    .padding(.vertical)
}
