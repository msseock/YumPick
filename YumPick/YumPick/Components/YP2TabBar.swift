import SwiftUI

/// 얌픽 v2.0 탭바. Pencil `BdU74` 디자인 기반의 5탭 플랫 구조.
/// 가운데 cut-out / 픽업 픽 버튼은 없애고 모든 탭을 평탄하게 표시한다.
struct YP2TabBar: View {
    @Binding var selectedTab: YPTab

    private let barHeight: CGFloat = 90
    private let bottomContentPadding: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home,
                    empty: "Home_Empty", fill: "Home_Fill", label: "홈")
            tabItem(tab: .order,
                    empty: "Order_Empty", fill: "Order_Fill", label: "주문")
            tabItem(tab: .pick,
                    empty: "Pick_Fill", fill: "Pick_Fill", label: "플레이")
            tabItem(tab: .community,
                    empty: "Community_Empty", fill: "Community_Fill", label: "커뮤니티")
            tabItem(tab: .profile,
                    empty: "Profile_Empty", fill: "Profile_Fill", label: "마이페이지")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomContentPadding)
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
        .background(
            YP2Color.paper
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(YP2Color.borderDefault)
                        .frame(height: 1)
                }
        )
    }

    @ViewBuilder
    private func tabItem(tab: YPTab, empty: String, fill: String, label: String) -> some View {
        let isSelected = selectedTab == tab
        let tint = isSelected ? YP2Color.ink : YP2Color.textSecondary

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(isSelected ? fill : empty)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(tint)

                Text(label)
                    .font(.custom(isSelected ? "Pretendard-Bold" : "Pretendard-Medium", size: 10))
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        YP2TabBar(selectedTab: .constant(.home))
    }
    .background(YP2Color.fog)
    .ignoresSafeArea()
}
