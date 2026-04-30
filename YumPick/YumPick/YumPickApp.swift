import SwiftUI
import FirebaseCore

@main
struct YumPickApp: App {
    @State private var authSession = AuthSession()
    @State private var router = AppRouter()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .environment(router)
                .task {
                    NetworkManager.configure(onSessionExpired: authSession.expire)
                }
        }
    }
}
