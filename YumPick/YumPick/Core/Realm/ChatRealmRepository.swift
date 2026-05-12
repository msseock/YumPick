import Foundation
import RealmSwift

protocol ChatRealmRepositoryProtocol {
    func savePending(_ message: ChatMessage, clientID: String) throws
    func markFailed(clientID: String) throws
    func replacePending(clientID: String, with message: ChatMessage) throws
    func deleteMessage(chatID: String) throws
    func deletePendingOrFailed(clientID: String) throws
    func saveAll(_ messages: [ChatMessage], isRoomOpen: Bool) throws
    func saveAllInitial(_ messages: [ChatMessage]) throws

    func fetchLatestMessages(roomID: String, limit: Int) throws -> [ChatMessage]
    func fetchMessagesBefore(roomID: String, before date: Date, limit: Int) throws -> [ChatMessage]
    func lastCreatedAt(roomID: String) throws -> Date?

    func markAllRead(roomID: String) throws
    func unreadCount(roomID: String) throws -> Int

    func fetchPendingOrFailed(limit: Int) throws -> [ChatPendingMessage]

    func isHidden(chatID: String) throws -> Bool
}

struct ChatPendingMessage {
    let clientID: String
    let roomID: String
    let content: String
    let files: [String]
    let status: ChatMessageStatus
}

final class ChatRealmRepository: ChatRealmRepositoryProtocol {
    private let configuration: Realm.Configuration

    init(configuration: Realm.Configuration = RealmConfig.make()) {
        self.configuration = configuration
    }

    func savePending(_ message: ChatMessage, clientID: String) throws {
        let realm = try Realm(configuration: configuration)
        let wasHidden = realm.object(ofType: ChatMessageObject.self, forPrimaryKey: message.chatID)?.isHidden ?? false
        let obj = message.toRealmObject(clientID: clientID, status: .sending)
        obj.isRead = true
        obj.isHidden = wasHidden
        try realm.write {
            realm.add(obj, update: .modified)
        }
    }

    func markFailed(clientID: String) throws {
        let realm = try Realm(configuration: configuration)
        guard let object = realm.objects(ChatMessageObject.self)
            .first(where: { $0.clientID == clientID }) else { return }
        try realm.write {
            object.status = ChatMessageStatus.failed.rawValue
        }
    }

    func replacePending(clientID: String, with message: ChatMessage) throws {
        let realm = try Realm(configuration: configuration)
        try realm.write {
            var wasHidden = false
            if let pending = realm.objects(ChatMessageObject.self)
                .first(where: { $0.clientID == clientID }) {
                wasHidden = pending.isHidden
                if pending.chatID != message.chatID {
                    realm.delete(pending)
                }
            }
            if let existing = realm.object(ofType: ChatMessageObject.self, forPrimaryKey: message.chatID) {
                wasHidden = wasHidden || existing.isHidden
            }
            let obj = message.toRealmObject(clientID: clientID, status: .sent)
            obj.isRead = true
            obj.isHidden = wasHidden
            realm.add(obj, update: .modified)
        }
    }

    func deleteMessage(chatID: String) throws {
        let realm = try Realm(configuration: configuration)
        guard let object = realm.object(ofType: ChatMessageObject.self, forPrimaryKey: chatID) else { return }
        try realm.write {
            object.isHidden = true
            object.isRead = true
        }
    }

    func deletePendingOrFailed(clientID: String) throws {
        let realm = try Realm(configuration: configuration)
        let sendingRaw = ChatMessageStatus.sending.rawValue
        let failedRaw = ChatMessageStatus.failed.rawValue
        guard let object = realm.objects(ChatMessageObject.self)
            .first(where: { $0.clientID == clientID && ($0.status == sendingRaw || $0.status == failedRaw) })
        else { return }
        try realm.write {
            realm.delete(object)
        }
    }

    func saveAll(_ messages: [ChatMessage], isRoomOpen: Bool) throws {
        let realm = try Realm(configuration: configuration)
        try realm.write {
            for message in messages {
                let wasHidden = realm.object(ofType: ChatMessageObject.self, forPrimaryKey: message.chatID)?.isHidden ?? false
                let obj = message.toRealmObject(status: .sent)
                obj.isRead = isRoomOpen
                obj.isHidden = wasHidden
                realm.add(obj, update: .modified)
            }
        }
    }

    func saveAllInitial(_ messages: [ChatMessage]) throws {
        let realm = try Realm(configuration: configuration)
        let todayUTC = Calendar(identifier: .gregorian).startOfDay(for: Date())
        try realm.write {
            for message in messages {
                let wasHidden = realm.object(ofType: ChatMessageObject.self, forPrimaryKey: message.chatID)?.isHidden ?? false
                let obj = message.toRealmObject(status: .sent)
                let createdAt = DateFormatManager.shared.date(fromChatISOString: message.createdAt) ?? .distantPast
                obj.isRead = createdAt < todayUTC
                obj.isHidden = wasHidden
                realm.add(obj, update: .modified)
            }
        }
    }

    func fetchLatestMessages(roomID: String, limit: Int) throws -> [ChatMessage] {
        let realm = try Realm(configuration: configuration)
        let results = realm.objects(ChatMessageObject.self)
            .where { $0.roomID == roomID && $0.isHidden == false }
            .sorted(byKeyPath: "createdAt", ascending: false)
            .prefix(limit)
        return results.reversed().map { $0.toDomain() }
    }

    func fetchMessagesBefore(roomID: String, before date: Date, limit: Int) throws -> [ChatMessage] {
        let realm = try Realm(configuration: configuration)
        let results = realm.objects(ChatMessageObject.self)
            .where { $0.roomID == roomID && $0.createdAt < date && $0.isHidden == false }
            .sorted(byKeyPath: "createdAt", ascending: false)
            .prefix(limit)
        return results.reversed().map { $0.toDomain() }
    }

    func lastCreatedAt(roomID: String) throws -> Date? {
        let realm = try Realm(configuration: configuration)
        return realm.objects(ChatMessageObject.self)
            .where { $0.roomID == roomID && $0.status == ChatMessageStatus.sent.rawValue }
            .sorted(byKeyPath: "createdAt", ascending: true)
            .last?
            .createdAt
    }

    func markAllRead(roomID: String) throws {
        let realm = try Realm(configuration: configuration)
        let unread = realm.objects(ChatMessageObject.self)
            .where { $0.roomID == roomID && $0.isRead == false }
        try realm.write {
            unread.forEach { $0.isRead = true }
        }
    }

    func unreadCount(roomID: String) throws -> Int {
        let realm = try Realm(configuration: configuration)
        return realm.objects(ChatMessageObject.self)
            .where { $0.roomID == roomID && $0.isRead == false && $0.isHidden == false }
            .count
    }

    func isHidden(chatID: String) throws -> Bool {
        let realm = try Realm(configuration: configuration)
        return realm.object(ofType: ChatMessageObject.self, forPrimaryKey: chatID)?.isHidden ?? false
    }

    func fetchPendingOrFailed(limit: Int) throws -> [ChatPendingMessage] {
        let realm = try Realm(configuration: configuration)
        let sendingRaw = ChatMessageStatus.sending.rawValue
        let failedRaw = ChatMessageStatus.failed.rawValue
        let results = realm.objects(ChatMessageObject.self)
            .where { $0.status == sendingRaw || $0.status == failedRaw }
            .sorted(byKeyPath: "createdAt", ascending: true)
            .prefix(limit)
        return results.map {
            ChatPendingMessage(
                clientID: $0.clientID,
                roomID: $0.roomID,
                content: $0.content,
                files: Array($0.files),
                status: $0.statusEnum
            )
        }
    }
}
