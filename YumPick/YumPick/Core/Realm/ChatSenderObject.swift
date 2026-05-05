import RealmSwift

final class ChatSenderObject: EmbeddedObject {
    @Persisted var userID: String = ""
    @Persisted var nick: String = ""
    @Persisted var profileImage: String?
}
