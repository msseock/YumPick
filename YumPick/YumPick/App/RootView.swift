import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(NetworkConnectivityMonitor.self) private var networkMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var isResolvingNetworkRecovery = false

    var body: some View {
        Group {
            if !networkMonitor.isConnected {
                NetworkUnavailableView(isRetrying: false) {
                    Task { await resolveNetworkAvailableWork() }
                }
            } else if isResolvingNetworkRecovery {
                LaunchView()
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
            await resolveNetworkAvailableWork()
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            guard isConnected else { return }
            Task { await resolveNetworkAvailableWork() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await resolveNetworkAvailableWork() }
        }
    }

    private func resolveNetworkAvailableWork() async {
        guard networkMonitor.isConnected else { return }

        let shouldBlockUI = authSession.state == .logoutRequired
            || authSession.needsAppleCredentialValidation

        if shouldBlockUI {
            isResolvingNetworkRecovery = true
            defer { isResolvingNetworkRecovery = false }
        }

        if authSession.state == .logoutRequired {
            await authSession.completeRequiredLogoutIfPossible()
        } else {
            await authSession.validateAppleCredentialIfNeeded(
                isNetworkConnected: networkMonitor.isConnected
            )
        }
    }
}
