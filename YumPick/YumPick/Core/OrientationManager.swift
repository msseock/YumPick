import UIKit

@MainActor
final class OrientationManager {
    static let shared = OrientationManager()
    private init() {}

    private(set) var allowsLandscape = false

    func lockLandscape() {
        allowsLandscape = true
        rotate(to: .landscape)
    }

    func lockPortrait() {
        allowsLandscape = false
        rotate(to: .portrait)
    }

    private func rotate(to mask: UIInterfaceOrientationMask) {
        guard let scene = activeWindowScene else { return }

        for window in scene.windows where window.isKeyWindow {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            print("Orientation geometry update failed: \(error.localizedDescription)")
        }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
