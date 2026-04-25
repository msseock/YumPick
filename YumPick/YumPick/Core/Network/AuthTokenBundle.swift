import Foundation

public struct AuthTokenBundle: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: String
    public let nick: String

    public init(accessToken: String, refreshToken: String, userID: String, nick: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.nick = nick
    }
}
