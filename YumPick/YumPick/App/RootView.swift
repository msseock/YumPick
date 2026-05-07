import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(NetworkConnectivityMonitor.self) private var networkMonitor

    var body: some View {
        Group {
            if !networkMonitor.isConnected {
                NetworkUnavailableView(isRetrying: false) {
                    Task { await retryNetworkBlockedWork() }
                }
            } else {
                switch authSession.state {
                case .checking, .logoutRequired:
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
            await retryNetworkBlockedWork()
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard isConnected else { return }
            Task { await retryNetworkBlockedWork() }
        }
    }

    private func retryNetworkBlockedWork() async {
        guard networkMonitor.isConnected else { return }
        if authSession.state == .logoutRequired {
            await authSession.completeRequiredLogoutIfPossible()
        }
    }
}
