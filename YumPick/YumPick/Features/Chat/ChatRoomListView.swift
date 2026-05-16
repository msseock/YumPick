import SwiftUI

struct ChatRoomListView: View {
    let onCompose: () -> Void
    let onSelectRoom: (String) -> Void
    @State private var viewModel = ChatRoomListViewModel()
    @State private var searchText = ""
    @Environment(NetworkConnectivityMonitor.self) private var networkMonitor

    init(
        onCompose: @escaping () -> Void = {},
        onSelectRoom: @escaping (String) -> Void
    ) {
        self.onCompose = onCompose
        self.onSelectRoom = onSelectRoom
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 12)

            content
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(YP2Color.backgroundPrimary)
        .navigationTitle("채팅")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.fetchRooms() }
        .onAppear {
            ChatPushHandler.shared.listViewModel = viewModel
            viewModel.refreshLocalState()
        }
        .onDisappear { ChatPushHandler.shared.listViewModel = nil }
        .onChange(of: networkMonitor.isConnected) { wasConnected, isConnected in
            guard !wasConnected, isConnected else { return }
            Task { await viewModel.fetchRooms() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(YP2Color.textTertiary)

            TextField("대화 상대 검색", text: $searchText)
                .ypFont(YPFont.body2Bold)
                .foregroundStyle(YP2Color.textPrimary)
                .tint(YP2Color.textPrimary)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(YP2Color.backgroundSecondary)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.rooms.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredRooms.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRooms) { room in
                        Button {
                            onSelectRoom(room.roomID)
                        } label: {
                            ChatRoomRow(
                                room: room,
                                opponent: viewModel.opponent(of: room),
                                unreadCount: viewModel.unreadCount(for: room),
                                lastChat: viewModel.lastChat(for: room)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .refreshable { await viewModel.fetchRooms() }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "아직 채팅방이 없어요" : "검색 결과가 없어요")
                .ypFont(YPFont.body2Bold)
                .foregroundStyle(YP2Color.textSecondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .ypFont(YPFont.caption1)
                    .foregroundStyle(YP2Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredRooms: [ChatRoom] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.rooms }

        return viewModel.rooms.filter { room in
            let opponent = viewModel.opponent(of: room)
            let lastChat = viewModel.lastChat(for: room)
            return opponent?.nick.localizedCaseInsensitiveContains(query) == true
                || lastChat?.content.localizedCaseInsensitiveContains(query) == true
        }
    }
}
