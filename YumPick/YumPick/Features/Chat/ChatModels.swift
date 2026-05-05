import Foundation
import RealmSwift

// MARK: - Domain Models

struct ChatMessage: Identifiable, Equatable, Decodable {
    let chatID: String
    let roomID: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let sender: ChatSender
    let files: [String]

    var id: String { chatID }

    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case roomID = "room_id"
        case content
        case createdAt
        case updatedAt
        case sender
        case files
    }
}

struct ChatSender: Equatable, Decodable {
    let userID: String
    let nick: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case profileImage
    }
}

struct ChatRoom: Identifiable, Equatable, Decodable {
    let roomID: String
    let createdAt: String
    let updatedAt: String
    let participants: [ChatSender]
    let lastChat: ChatMessage?

    var id: String { roomID }

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case createdAt
        case updatedAt
        case participants
        case lastChat
    }

    func opponent(currentUserID: String?) -> ChatSender? {
        guard let currentUserID else { return participants.first }
        return participants.first { $0.userID != currentUserID } ?? participants.first
    }
}

// MARK: - Realm Conversion

extension ChatMessage {
    func toRealmObject(clientID: String? = nil, status: ChatMessageStatus = .sent) -> ChatMessageObject {
        let object = ChatMessageObject()
        object.chatID = chatID
        object.clientID = clientID ?? chatID
        object.roomID = roomID
        object.content = content
        object.createdAt = DateFormatManager.shared.date(fromChatISOString: createdAt) ?? Date()
        object.updatedAt = DateFormatManager.shared.date(fromChatISOString: updatedAt) ?? object.createdAt
        object.status = status.rawValue

        let senderObject = ChatSenderObject()
        senderObject.userID = sender.userID
        senderObject.nick = sender.nick
        senderObject.profileImage = sender.profileImage
        object.sender = senderObject

        files.forEach { object.files.append($0) }
        return object
    }
}

extension ChatMessageObject {
    func toDomain() -> ChatMessage {
        ChatMessage(
            chatID: chatID,
            roomID: roomID,
            content: content,
            createdAt: DateFormatManager.shared.chatISOString(from: createdAt),
            updatedAt: DateFormatManager.shared.chatISOString(from: updatedAt),
            sender: ChatSender(
                userID: sender?.userID ?? "",
                nick: sender?.nick ?? "",
                profileImage: sender?.profileImage
            ),
            files: Array(files)
        )
    }

    var statusEnum: ChatMessageStatus {
        ChatMessageStatus(rawValue: status) ?? .sent
    }
}

// MARK: - UserSession + ChatSender

extension UserSession {
    var asSender: ChatSender? {
        guard let id = userID, let nick else { return nil }
        return ChatSender(userID: id, nick: nick, profileImage: profileImage)
    }
}
