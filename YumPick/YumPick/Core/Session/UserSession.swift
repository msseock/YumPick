import Foundation

final class UserSession {
    static let shared = UserSession()

    var userID: String?
    var nick: String?
    var profileImage: String?

    private init() {}

    func set(from bundle: AuthTokenBundle) {
        set(userID: bundle.userID, nick: bundle.nick)
    }

    func set(userID: String, nick: String, profileImage: String? = nil) {
        self.userID = userID
        self.nick = nick
        self.profileImage = profileImage
        Task { @MainActor in
            ChatUserDirectory.shared.upsert(
                ChatSender(userID: userID, nick: nick, profileImage: profileImage)
            )
        }
    }

    func clear() {
        userID = nil
        nick = nil
        profileImage = nil
    }

}
