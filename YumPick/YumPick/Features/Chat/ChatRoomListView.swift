import SwiftUI

struct ChatRoomListView: View {
    let onSelectRoom: (String) -> Void
    @State private var viewModel = ChatRoomListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rooms.isEmpty {
                ProgressView()
            } else if viewModel.rooms.isEmpty {
                Text("아직 채팅방이 없어요")
                    .ypFont(YPFont.body2)
                    .foregroundStyle(YPColor.textSecondary)
            } else {
                List(viewModel.rooms) { room in
                    Button {
                        onSelectRoom(room.roomID)
                    } label: {
                        ChatRoomRow(
                            room: room,
                            opponent: viewModel.opponent(of: room),
                            unreadCount: viewModel.unreadCount(for: room)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .refreshable { await viewModel.fetchRooms() }
            }
        }
        .task { await viewModel.fetchRooms() }
        .onAppear { ChatPushHandler.shared.listViewModel = viewModel }
        .onDisappear { ChatPushHandler.shared.listViewModel = nil }
    }
}
