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
}
