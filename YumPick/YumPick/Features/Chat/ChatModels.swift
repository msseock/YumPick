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
        case created_at
        case updatedAt
        case updated_at
        case sender
        case files
    }

    init(
        chatID: String,
        roomID: String,
        content: String,
        createdAt: String,
        updatedAt: String,
        sender: ChatSender,
        files: [String]
    ) {
        self.chatID = chatID
        self.roomID = roomID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sender = sender
        self.files = files
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chatID = try container.decode(String.self, forKey: .chatID)
        roomID = try container.decode(String.self, forKey: .roomID)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decode(String.self, forKey: .created_at)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? container.decode(String.self, forKey: .updated_at)
        sender = try container.decode(ChatSender.self, forKey: .sender)
        files = try container.decodeIfPresent([String].self, forKey: .files) ?? []
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
        case profile_image
    }

    init(userID: String, nick: String, profileImage: String?) {
        self.userID = userID
        self.nick = nick
        self.profileImage = profileImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        nick = try container.decode(String.self, forKey: .nick)
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
            ?? container.decodeIfPresent(String.self, forKey: .profile_image)
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
        case created_at
        case updatedAt
        case updated_at
        case participants
        case lastChat
        case last_chat
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomID = try container.decode(String.self, forKey: .roomID)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decode(String.self, forKey: .created_at)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? container.decode(String.self, forKey: .updated_at)
        participants = try container.decode([ChatSender].self, forKey: .participants)
        lastChat = try container.decodeIfPresent(ChatMessage.self, forKey: .lastChat)
            ?? container.decodeIfPresent(ChatMessage.self, forKey: .last_chat)
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
