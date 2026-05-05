import Foundation

@Observable
@MainActor
final class ChatRoomListViewModel {
    private(set) var rooms: [ChatRoom] = []
    private(set) var unreadCounts: [String: Int] = [:]
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    private let client: ChatClientProtocol
    private let repository: ChatRealmRepositoryProtocol

    init(
        client: ChatClientProtocol = ChatClient(),
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
            refreshUnreadCounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUnreadCounts() {
        var counts: [String: Int] = [:]
        rooms.forEach { room in
            counts[room.roomID] = (try? repository.unreadCount(roomID: room.roomID)) ?? 0
        }
        unreadCounts = counts
    }

    func opponent(of room: ChatRoom) -> ChatSender? {
        room.opponent(currentUserID: UserSession.shared.userID)
    }

    func unreadCount(for room: ChatRoom) -> Int {
        unreadCounts[room.roomID] ?? 0
    }
}
