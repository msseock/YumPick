import Foundation
import RealmSwift

final class ChatMessageObject: Object {
    @Persisted(primaryKey: true) var chatID: String = ""
    @Persisted var roomID: String = ""
    @Persisted var content: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var sender: ChatSenderObject?
    @Persisted var files: List<String>
    @Persisted var status: String = ChatMessageStatus.sent.rawValue
    @Persisted var isRead: Bool = false
    @Persisted var isHidden: Bool = false
}

enum ChatMessageStatus: String {
    case sending
    case sent
    case failed
}
