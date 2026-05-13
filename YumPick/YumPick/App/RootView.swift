import SwiftUI

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(NetworkConnectivityMonitor.self) private var networkMonitor
    @Environment(\.scenePhase) private var scenePhase
    @State private var isResolvingNetworkRecovery = false

    var body: some View {
        Group {
            if shouldBlockForNetworkUnavailable {
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
            guard isConnected, !FixtureFileResolver.usesFixtures else { return }
            Task { await resolveNetworkAvailableWork() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !FixtureFileResolver.usesFixtures else { return }
            Task { await resolveNetworkAvailableWork() }
        }
        .onChange(of: authSession.state, initial: true) { _, newState in
            ChatPushHandler.shared.setAuthenticated(newState == .authenticated)
        }
    }

    private var shouldBlockForNetworkUnavailable: Bool {
        !FixtureFileResolver.usesFixtures && !networkMonitor.isConnected
    }

    private func resolveNetworkAvailableWork() async {
        guard !FixtureFileResolver.usesFixtures else { return }
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
