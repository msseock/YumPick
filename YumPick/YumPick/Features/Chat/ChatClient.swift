import Foundation

// MARK: - Protocol

protocol ChatClientProtocol {
    func createOrFetchRoom(opponentUserID: String) async throws -> ChatRoom
    func fetchRooms() async throws -> [ChatRoom]
    func fetchMessages(roomID: String, next: String?) async throws -> [ChatMessage]
    func sendMessage(roomID: String, content: String, files: [String]) async throws -> ChatMessage
    func uploadFiles(roomID: String, parts: [MultipartData]) async throws -> [String]
}

// MARK: - Endpoint

private enum ChatEndpoint: Endpoint {
    case createRoom(CreateChatRoomRequest)
    case rooms
    case messages(roomID: String, next: String?)
    case sendMessage(roomID: String, SendChatMessageRequest)
    case uploadFiles(roomID: String, parts: [MultipartData])

    var path: String {
        switch self {
        case .createRoom, .rooms:
            return "/v1/chats"
        case .messages(let roomID, _):
            return "/v1/chats/\(roomID)"
        case .sendMessage(let roomID, _):
            return "/v1/chats/\(roomID)"
        case .uploadFiles(let roomID, _):
            return "/v1/chats/\(roomID)/files"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .rooms, .messages:
            return .get
        case .createRoom, .sendMessage, .uploadFiles:
            return .post
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .createRoom(let body):
            return .body(body)
        case .rooms:
            return .none
        case .messages(_, let next):
            guard let next, !next.isEmpty else { return .none }
            return .query(["next": next])
        case .sendMessage(_, let body):
            return .body(body)
        case .uploadFiles(_, let parts):
            return .multipart(parts)
        }
    }
}

// MARK: - Request / Response DTO

private struct CreateChatRoomRequest: Encodable {
    let opponent_id: String
}

private struct SendChatMessageRequest: Encodable {
    let content: String
    let files: [String]
}

private struct ChatRoomListResponse: Decodable {
    let data: [ChatRoom]
}

private struct ChatListResponse: Decodable {
    let data: [ChatMessage]
}

private struct ChatFileResponse: Decodable {
    let files: [String]
}

// MARK: - Real Implementation

final class ChatClient: ChatClientProtocol {
    func createOrFetchRoom(opponentUserID: String) async throws -> ChatRoom {
        try await NetworkManager.shared.request(
            ChatEndpoint.createRoom(CreateChatRoomRequest(opponent_id: opponentUserID))
        )
    }

    func fetchRooms() async throws -> [ChatRoom] {
        let response: ChatRoomListResponse = try await NetworkManager.shared.request(ChatEndpoint.rooms)
        return response.data
    }

    func fetchMessages(roomID: String, next: String?) async throws -> [ChatMessage] {
        let response: ChatListResponse = try await NetworkManager.shared.request(
            ChatEndpoint.messages(roomID: roomID, next: next)
        )
        return response.data
    }

    func sendMessage(roomID: String, content: String, files: [String]) async throws -> ChatMessage {
        try await NetworkManager.shared.request(
            ChatEndpoint.sendMessage(roomID: roomID, SendChatMessageRequest(content: content, files: files))
        )
    }

    func uploadFiles(roomID: String, parts: [MultipartData]) async throws -> [String] {
        let response: ChatFileResponse = try await NetworkManager.shared.request(
            ChatEndpoint.uploadFiles(roomID: roomID, parts: parts)
        )
        return response.files
    }
}

// MARK: - Mock

final class MockChatClient: ChatClientProtocol {
    var createOrFetchRoomResult: Result<ChatRoom, Error> = .failure(MockError.notImplemented)
    var fetchRoomsResult: Result<[ChatRoom], Error> = .success([])
    var fetchMessagesResult: Result<[ChatMessage], Error> = .success([])
    var sendMessageResult: Result<ChatMessage, Error> = .failure(MockError.notImplemented)
    var uploadFilesResult: Result<[String], Error> = .success([])

    enum MockError: Error { case notImplemented }

    func createOrFetchRoom(opponentUserID: String) async throws -> ChatRoom { try createOrFetchRoomResult.get() }
    func fetchRooms() async throws -> [ChatRoom] { try fetchRoomsResult.get() }
    func fetchMessages(roomID: String, next: String?) async throws -> [ChatMessage] { try fetchMessagesResult.get() }
    func sendMessage(roomID: String, content: String, files: [String]) async throws -> ChatMessage { try sendMessageResult.get() }
    func uploadFiles(roomID: String, parts: [MultipartData]) async throws -> [String] { try uploadFilesResult.get() }
}
