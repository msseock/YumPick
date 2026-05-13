import Foundation

@Observable
@MainActor
final class ChatRoomListViewModel {
    private(set) var rooms: [ChatRoom] = []
    private(set) var unreadCounts: [String: Int] = [:]
    private(set) var lastChats: [String: ChatMessage] = [:]
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    private let client: ChatClientProtocol
    private let repository: ChatRealmRepositoryProtocol

    init(
        client: ChatClientProtocol = FixtureClientFactory.chatClient(),
        repository: ChatRealmRepositoryProtocol = ChatRealmRepository()
    ) {
        self.client = client
        self.repository = repository
    }

    func fetchRooms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rooms = try await client.fetchRooms()
            ChatUserDirectory.shared.upsert(rooms.flatMap(\.participants))
            refreshLocalState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLocalState() {
        refreshUnreadCounts()
        refreshLastChats()
    }

    func refreshUnreadCounts() {
        var counts: [String: Int] = [:]
        rooms.forEach { room in
            counts[room.roomID] = (try? repository.unreadCount(roomID: room.roomID)) ?? 0
        }
        unreadCounts = counts
    }

    func refreshLastChats() {
        var resolved: [String: ChatMessage] = [:]
        rooms.forEach { room in
            guard let serverLast = room.lastChat else { return }
            let hidden = (try? repository.isHidden(chatID: serverLast.chatID)) ?? false
            if !hidden {
                resolved[room.roomID] = serverLast
                return
            }
            if let fallback = (try? repository.fetchLatestMessages(roomID: room.roomID, limit: 1))?.last {
                resolved[room.roomID] = fallback
            }
        }
        lastChats = resolved
    }

    func opponent(of room: ChatRoom) -> ChatSender? {
        room.opponent(currentUserID: UserSession.shared.userID)
    }

    func unreadCount(for room: ChatRoom) -> Int {
        unreadCounts[room.roomID] ?? 0
    }

    func lastChat(for room: ChatRoom) -> ChatMessage? {
        lastChats[room.roomID]
    }
}
