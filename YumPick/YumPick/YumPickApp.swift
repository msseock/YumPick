import SwiftUI
import FirebaseCore
import iamport_ios

@main
struct YumPickApp: App {
    @State private var authSession = AuthSession()
    @State private var router = AppRouter()
    @State private var networkMonitor = NetworkConnectivityMonitor()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .environment(router)
                .environment(networkMonitor)
                .task {
                    NetworkManager.configure(onSessionExpired: authSession.expire)
                    ChatPushHandler.shared.configure(router: router)
                }
                .onOpenURL { url in
                    Iamport.shared.receivedURL(url)
                }
        }
    }
}
