import SwiftUI

struct TabBarView: View {
    @Environment(AppRouter.self) private var router

    private var shouldShowTabBar: Bool {
        switch router.selectedTab {
        case .home: router.homePath.isEmpty
        case .order: router.orderPath.isEmpty
        case .pick: router.pickPath.isEmpty
        case .community: router.communityPath.isEmpty
        case .profile: router.profilePath.isEmpty
        }
    }

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            ZStack {
                LazyTabView(isSelected: router.selectedTab == .home) {
                    HomeTabView(path: $router.homePath)
                }
                LazyTabView(isSelected: router.selectedTab == .order) {
                    OrderTabView(path: $router.orderPath)
                }
                LazyTabView(isSelected: router.selectedTab == .pick) {
                    PickTabView(path: $router.pickPath)
                }
                LazyTabView(isSelected: router.selectedTab == .community) {
                    CommunityTabView(path: $router.communityPath)
                }
                LazyTabView(isSelected: router.selectedTab == .profile) {
                    ProfileTabView(path: $router.profilePath)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowTabBar {
                YP2TabBar(selectedTab: $router.selectedTab)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(YP2Color.backgroundPrimary)
    }
}
