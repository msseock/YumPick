import Foundation

final class UserSession {
    static let shared = UserSession()

    var userID: String?
    var nick: String?
    var profileImage: String?

    private init() {}

    func set(from bundle: AuthTokenBundle) {
        userID = bundle.userID
        nick = bundle.nick
    }

    func clear() {
        userID = nil
        nick = nil
        profileImage = nil
    }

    // asSender는 ChatSender 도메인 타입 정의(ChatClient.swift) 후 extension으로 추가

}
