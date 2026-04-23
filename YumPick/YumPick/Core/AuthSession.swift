import Foundation

/// 앱 전역 인증 상태 관리.
/// 현재는 NotificationCenter로 세션 만료를 전파하며,
/// TODO: @Observable + LoginFlow/MainFlow 전환 로직으로 교체 필요 (session-flow.md 참고)
final class AuthSession {
    static let shared = AuthSession()
    private init() {}

    func expire() {
        NotificationCenter.default.post(name: .refreshTokenExpired, object: nil)
    }
}

extension Notification.Name {
    static let refreshTokenExpired = Notification.Name("refreshTokenExpired")
}
