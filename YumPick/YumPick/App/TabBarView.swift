import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: YPTab = .home
    @State private var homePath: [HomePath] = []
    @State private var orderPath: [OrderPath] = []
    @State private var pickPath: [PickPath] = []
    @State private var communityPath: [CommunityPath] = []
    @State private var profilePath: [ProfilePath] = []

    private var shouldShowTabBar: Bool {
        switch selectedTab {
        case .home:
            homePath.isEmpty
        case .order:
            orderPath.isEmpty
        case .pick:
            pickPath.isEmpty
        case .community:
            communityPath.isEmpty
        case .profile:
            profilePath.isEmpty
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                LazyTabView(isSelected: selectedTab == .home) {
                    HomeTabView(path: $homePath)
                }
                LazyTabView(isSelected: selectedTab == .order) {
                    OrderTabView(path: $orderPath)
                }
                LazyTabView(isSelected: selectedTab == .pick) {
                    PickTabView(path: $pickPath)
                }
                LazyTabView(isSelected: selectedTab == .community) {
                    CommunityTabView(path: $communityPath)
                }
                LazyTabView(isSelected: selectedTab == .profile) {
                    ProfileTabView(path: $profilePath)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowTabBar {
                YPTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(YPColor.backgroundPrimary)
    }
}
