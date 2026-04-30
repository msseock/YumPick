import Foundation

@Observable
final class AppRouter {
    var selectedTab: YPTab = .home
    var homePath: [HomePath] = []
    var orderPath: [OrderPath] = []
    var pickPath: [PickPath] = []
    var communityPath: [CommunityPath] = []
    var profilePath: [ProfilePath] = []

    private(set) var orderReloadToken: UUID = UUID()

    func bumpOrderReload() {
        orderReloadToken = UUID()
    }
}
