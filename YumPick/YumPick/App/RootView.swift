import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession

    var body: some View {
        Group {
            switch authSession.state {
            case .checking:
                LaunchView()
            case .authenticated:
                TabBarView()
            case .unauthenticated, .expired:
                LoginView()
            }
        }
        .task {
            if authSession.state == .checking {
                authSession.restore()
            }
        }
    }
}
