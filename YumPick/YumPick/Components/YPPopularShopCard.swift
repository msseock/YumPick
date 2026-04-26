import SwiftUI

struct YPPopularShopCard: View {
    var imagePath: String?
    var shopName: String
    var pickupCount: Int
    var distance: String
    var closeTime: String
    var visitCount: Int
    var isLiked: Bool
    var isPickchelin: Bool
    var onLikeTapped: () -> Void

    private let cardWidth: CGFloat = 240
    private let imageHeight: CGFloat = 120
    private let infoHeight: CGFloat = 56
    private let likeButtonSize: CGFloat = 24
    private let likeButtonPadding: CGFloat = 8
    private let imageCutoutCornerRadius: CGFloat = 14

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                CachedImage(path: imagePath)
                    .frame(width: cardWidth, height: imageHeight)
                    .clipShape(
                        TopLeadingCutoutShape(
                            cutoutSize: likeButtonSize + likeButtonPadding * 2,
                            cornerRadius: imageCutoutCornerRadius
                        )
                    )

                infoView
                    .frame(width: cardWidth, height: infoHeight)
                    .background(YPColor.backgroundPrimary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: Color(red: 123/255, green: 120/255, blue: 134/255, opacity: 0.08),
                radius: 6, x: 0, y: 4
            )

            // Like button (좌상단)
            YPLikeButton(isLiked: isLiked, action: onLikeTapped)
                .padding(likeButtonPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Pickchelin tag (우상단)
            if isPickchelin {
                YPPickchelinTag()
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: cardWidth, height: imageHeight + infoHeight)
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(shopName)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    Image("Like_Fill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(YPColor.actionAccent)

                    Text("\(pickupCount)개")
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YPColor.textPrimary)
                }
            }

            HStack(spacing: 16) {
                statItem(icon: "Distance", text: distance)
                statItem(icon: "Time", text: closeTime)
                statItem(icon: "Run", text: "\(visitCount)회")
            }
        }
        .padding(.leading, 10)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(YPColor.textSecondary)

            Text(text)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
        }
    }
}

private struct TopLeadingCutoutShape: Shape {
    var cutoutSize: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let size = min(cutoutSize, rect.width, rect.height)
        let radius = min(cornerRadius, size)
        let circleControlPointRatio = 0.5522847498

        var path = Path()
        path.move(to: CGPoint(x: size + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: size + radius))
        path.addCurve(
            to: CGPoint(x: radius, y: size),
            control1: CGPoint(x: rect.minX, y: size + radius - radius * circleControlPointRatio),
            control2: CGPoint(x: radius - radius * circleControlPointRatio, y: size)
        )
        path.addLine(to: CGPoint(x: size - radius, y: size))
        path.addCurve(
            to: CGPoint(x: size, y: size - radius),
            control1: CGPoint(x: size - radius + radius * circleControlPointRatio, y: size),
            control2: CGPoint(x: size, y: size - radius + radius * circleControlPointRatio)
        )
        path.addLine(to: CGPoint(x: size, y: radius))
        path.addCurve(
            to: CGPoint(x: size + radius, y: rect.minY),
            control1: CGPoint(x: size, y: radius - radius * circleControlPointRatio),
            control2: CGPoint(x: size + radius - radius * circleControlPointRatio, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 12) {
        YPPopularShopCard(
            imagePath: nil,
            shopName: "새싹 도넛 가게",
            pickupCount: 126,
            distance: "3.2km",
            closeTime: "7PM",
            visitCount: 135,
            isLiked: true,
            isPickchelin: true,
            onLikeTapped: {}
        )
    }
    .padding()
    .background(YPColor.backgroundBrandSubtle)
}
