import SwiftUI

enum ProfilePath: Hashable {
    case chatRooms
    case chatRoom(String)
}

struct ProfileTabView: View {
    @Binding var path: [ProfilePath]

    var body: some View {
        NavigationStack(path: $path) {
            ProfileView()
                .navigationDestination(for: ProfilePath.self) { destination in
                    switch destination {
                    case .chatRooms:
                        ChatRoomListView { roomID in path.append(.chatRoom(roomID)) }
                    case .chatRoom(let roomID):
                        ChatView(roomID: roomID)
                    }
                }
        }
    }
}
