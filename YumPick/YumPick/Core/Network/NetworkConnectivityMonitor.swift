import Foundation
import Network

@MainActor
@Observable
final class NetworkConnectivityMonitor {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.yumpick.network-connectivity")

    private(set) var isConnected = true

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        self.monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
