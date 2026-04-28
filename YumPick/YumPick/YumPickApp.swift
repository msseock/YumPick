import SwiftUI
import FirebaseCore

@main
struct YumPickApp: App {
    @State private var authSession = AuthSession()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

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
