import Foundation
import RealmSwift

final class ChatUserProfileObject: Object {
    @Persisted(primaryKey: true) var userID: String = ""
    @Persisted var nick: String = ""
    @Persisted var profileImage: String?
    @Persisted var updatedAt: Date = Date()
}
