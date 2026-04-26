import SwiftUI

enum YPTab {
    case home, order, pick, community, profile
}

// 가운데 원형 cut-out이 있는 탭바 배경 Shape
private struct TabBarBackgroundShape: Shape {
    var cutoutRadius: CGFloat
    var cutoutCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let cornerRadius = min(cutoutCornerRadius, cutoutRadius * 0.45)
        let transitionAngle = min(
            35,
            max(16, Double(cornerRadius / cutoutRadius * 90))
        )
        let radians = Angle(degrees: transitionAngle).radians
        let cosAngle = CGFloat(cos(radians))
        let sinAngle = CGFloat(sin(radians))
        let arcTangentLength = cornerRadius * 0.8
        let lineTangentLength = cornerRadius * 0.65

        let leftCornerStart = CGPoint(
            x: midX - cutoutRadius - cornerRadius,
            y: rect.minY
        )
        let leftArcStart = CGPoint(
            x: midX - cutoutRadius * cosAngle,
            y: rect.minY + cutoutRadius * sinAngle
        )
        let rightArcEnd = CGPoint(
            x: midX + cutoutRadius * cosAngle,
            y: rect.minY + cutoutRadius * sinAngle
        )
        let rightCornerEnd = CGPoint(
            x: midX + cutoutRadius + cornerRadius,
            y: rect.minY
        )
        var path = Path()

        // 좌상단 시작
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // 상단 좌측 → cut-out 왼쪽 라운드 시작
        path.addLine(to: leftCornerStart)

        // cut-out과 상단 선이 만나는 지점을 부드럽게 연결
        path.addCurve(
            to: leftArcStart,
            control1: CGPoint(
                x: leftCornerStart.x + lineTangentLength,
                y: leftCornerStart.y
            ),
            control2: CGPoint(
                x: leftArcStart.x - sinAngle * arcTangentLength,
                y: leftArcStart.y - cosAngle * arcTangentLength
            )
        )

        // 오목한 cut-out 호 (상단을 기준으로 아래로 파임)
        path.addArc(
            center: CGPoint(x: midX, y: rect.minY),
            radius: cutoutRadius,
            startAngle: .degrees(180 - transitionAngle),
            endAngle: .degrees(transitionAngle),
            clockwise: true
        )

        // cut-out 오른쪽 라운드 끝 → 우상단
        path.addCurve(
            to: rightCornerEnd,
            control1: CGPoint(
                x: rightArcEnd.x + sinAngle * arcTangentLength,
                y: rightArcEnd.y - cosAngle * arcTangentLength
            ),
            control2: CGPoint(
                x: rightCornerEnd.x - lineTangentLength,
                y: rightCornerEnd.y
            )
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // 우측 → 하단 → 좌측
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

struct YPTabBar: View {
    @Binding var selectedTab: YPTab

    private let barHeight: CGFloat = 80
    private let buttonSize: CGFloat = 56
    private let buttonTopPadding: CGFloat = -12
    private let centerButtonOffset: CGFloat = -26
    private let cutoutRadius: CGFloat = 38
    private let cutoutCornerRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .top) {
            // 배경
            TabBarBackgroundShape(
                cutoutRadius: cutoutRadius,
                cutoutCornerRadius: cutoutCornerRadius
            )
            .fill(YPColor.backgroundPrimary)
            .shadow(
                color: Color(
                    red: 105 / 255,
                    green: 105 / 255,
                    blue: 105 / 255,
                    opacity: 0.1
                ),
                radius: 6,
                x: 0,
                y: -4
            )
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)

            // 탭 아이템 (좌 2개 + 우 2개)
            HStack(spacing: 0) {
                tabItemView(tab: .home, empty: "Home_Empty", fill: "Home_Fill")
                tabItemView(
                    tab: .order,
                    empty: "Order_Empty",
                    fill: "Order_Fill"
                )
                Spacer().frame(width: buttonSize + 16)
                tabItemView(
                    tab: .community,
                    empty: "Community_Empty",
                    fill: "Community_Fill"
                )
                tabItemView(
                    tab: .profile,
                    empty: "Profile_Empty",
                    fill: "Profile_Fill"
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .offset(y: buttonTopPadding)

            // 가운데 픽업 버튼
            Button {
                selectedTab = .pick
            } label: {
                ZStack {
                    Circle()
                        .fill(YPColor.brandBlackSprout)
                        .frame(width: buttonSize, height: buttonSize)

                    Image("Pick_Fill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(YPColor.backgroundPrimary)
                }
            }
            .offset(y: centerButtonOffset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
    }

    @ViewBuilder
    private func tabItemView(tab: YPTab, empty: String, fill: String)
        -> some View
    {
        let isSelected = selectedTab == tab
        Button {
            selectedTab = tab
        } label: {
            Image(isSelected ? fill : empty)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundStyle(
                    isSelected ? YPColor.brandBlackSprout : YPColor.textTertiary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        YPTabBar(selectedTab: .constant(.home))
    }
    .background(YPColor.backgroundSecondary)
    .ignoresSafeArea()
}
