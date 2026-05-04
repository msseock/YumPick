import Foundation

enum CurrentUser {
    static var id: String? { KeychainManager.shared.read(key: .userID) }
    static var nick: String? { KeychainManager.shared.read(key: .nick) }
}
