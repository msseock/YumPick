import SwiftUI

@main
struct YumPickApp: App {
    @State private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .task {
                    NetworkManager.configure(onSessionExpired: authSession.expire)
                }
        }
    }
}
