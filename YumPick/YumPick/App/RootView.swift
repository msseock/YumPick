import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(NetworkConnectivityMonitor.self) private var networkMonitor

    var body: some View {
        Group {
            if !networkMonitor.isConnected {
                NetworkUnavailableView(isRetrying: false) {
                    Task { await authSession.restore() }
                }
            } else {
                switch authSession.state {
                case .checking:
                    LaunchView()
                case .authenticated:
                    TabBarView()
                case .unauthenticated, .expired:
                    LoginView()
                }
            }
        }
        .task {
            if authSession.state == .checking {
                await authSession.restore()
            }
        }
    }
}
