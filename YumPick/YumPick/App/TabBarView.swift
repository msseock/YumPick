import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: YPTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                LazyTabView(isSelected: selectedTab == .home)        { HomeTabView() }
                LazyTabView(isSelected: selectedTab == .order)       { OrderTabView() }
                LazyTabView(isSelected: selectedTab == .pick)        { PickTabView() }
                LazyTabView(isSelected: selectedTab == .community)   { CommunityTabView() }
                LazyTabView(isSelected: selectedTab == .profile)     { ProfileTabView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            YPTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(YPColor.backgroundPrimary)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            Text("홈")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .order:
            Text("주문")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .pick:
            Text("픽업")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .community:
            Text("커뮤니티")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .profile:
            VStack(spacing: 24) {
                Text("마이페이지")
                    .font(YPFont.title1)
                    .foregroundStyle(YPColor.textPrimary)

                Button("로그아웃") {
                    Task {
                        try? await LoginClient().logout()
                        authSession.logout()
                    }
                }
                .font(YPFont.body2)
                .foregroundStyle(YPColor.backgroundPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(YPColor.actionPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
