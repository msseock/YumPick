import SwiftUI

private struct PickchelinTagShape: Shape {
    var notchDepth: CGFloat = 6
    var endRadius: CGFloat = 2.5

    func path(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        let notchPoint = CGPoint(x: rect.maxX - notchDepth, y: rect.midY)
        let topEndPoint = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomEndPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        var path = Path()

        // 왼쪽 반원 상단에서 시작
        path.move(to: CGPoint(x: radius, y: 0))

        // 오른쪽 상단 끝점을 둥글게 처리한 뒤 가운데 노치는 뾰족하게 유지
        path.addArc(
            tangent1End: topEndPoint,
            tangent2End: notchPoint,
            radius: endRadius
        )
        path.addLine(to: notchPoint)

        // 오른쪽 하단 끝점도 둥글게 처리
        path.addArc(
            tangent1End: bottomEndPoint,
            tangent2End: CGPoint(x: radius, y: rect.maxY),
            radius: endRadius
        )
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))

        // 왼쪽 반원 (하단 → 좌측 → 상단)
        path.addArc(
            center: CGPoint(x: radius, y: rect.midY),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(-90),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

struct YPPickchelinTag: View {
    var body: some View {
        ZStack {
            PickchelinTagShape()
                .fill(YPColor.brandBlackSprout)
            PickchelinTagShape()
                .stroke(YPColor.brandBrightSprout, lineWidth: 1)

            HStack(spacing: 4) {
                Image("Pick_Fill")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(YPColor.backgroundPrimary)

                Text("픽슐랭")
                    .font(YPFont.caption2)
                    .foregroundStyle(YPColor.backgroundPrimary)
            }
            .offset(x: -2)
        }
        .frame(width: 61, height: 20)
    }
}

#Preview {
    YPPickchelinTag()
        .padding()
        .background(.black)
}
