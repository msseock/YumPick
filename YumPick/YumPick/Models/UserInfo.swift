import Foundation

struct UserInfo: Codable, Hashable {
    let user_id: String
    let nick: String
    let profileImage: String?
}
