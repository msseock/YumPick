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

}
