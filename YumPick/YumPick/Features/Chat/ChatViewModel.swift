import Combine
import Foundation

@Observable
@MainActor
final class ChatViewModel {
    private enum PagePolicy {
        static let initialLocalLimit = 50
        static let olderPageSize = 30
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var pendingClientIDs: Set<String> = []
    private(set) var failedClientIDs: Set<String> = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingOlder: Bool = false
    private(set) var isSending: Bool = false
    var errorMessage: String?

    private(set) var currentRoomID: String
    private let currentUserID: String?
    private let client: ChatClientProtocol
    private let socketManager: ChatSocketManagerProtocol
    private let repository: ChatRealmRepositoryProtocol
    private let outbox: ChatOutboxWorker
    private var cancellables = Set<AnyCancellable>()
    private var isAppeared = false

    init(
        roomID: String,
        currentUserID: String? = KeychainManager.shared.read(key: .userID),
        client: ChatClientProtocol = ChatClient(),
        socketManager: ChatSocketManagerProtocol = ChatSocketManager(),
        repository: ChatRealmRepositoryProtocol = ChatRealmRepository(),
        outbox: ChatOutboxWorker = .shared
    ) {
        self.currentRoomID = roomID
        self.currentUserID = currentUserID
        self.client = client
        self.socketManager = socketManager
        self.repository = repository
        self.outbox = outbox
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isAppeared else { return }
        isAppeared = true
        bindSocket()
        loadInitialLocalMessages()
        socketManager.connect(roomID: currentRoomID)
        Task { await syncRecentMessages() }
        outbox.start()
    }

    func onDisappear() {
        isAppeared = false
        socketManager.disconnect()
        cancellables.removeAll()
    }

    // MARK: - Pagination

    func loadOlderMessagesIfNeeded(current message: ChatMessage) {
        guard message.id == messages.first?.id else { return }
        Task { await loadOlderMessages() }
    }

    func loadOlderMessages() async {
        guard !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            guard let oldestDate = DateFormatManager.shared.date(fromChatISOString: oldest.createdAt) else { return }
            let older = try repository.fetchMessagesBefore(
                roomID: currentRoomID,
                before: oldestDate,
                limit: PagePolicy.olderPageSize
            )
            guard !older.isEmpty else { return }
            messages = mergeMessages(older + messages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send (Optimistic)

    func sendMessage(content: String, files: [String] = []) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !files.isEmpty else { return }
        guard let me = UserSession.shared.asSender else {
            errorMessage = "로그인 상태를 확인해주세요."
            return
        }

        let clientID = UUID().uuidString
        let nowISO = DateFormatManager.shared.chatISOString(from: Date())
        let pending = ChatMessage(
            chatID: clientID,
            roomID: currentRoomID,
            content: trimmed,
            createdAt: nowISO,
            updatedAt: nowISO,
            sender: me,
            files: files
        )

        do {
            try repository.savePending(pending, clientID: clientID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        pendingClientIDs.insert(clientID)
        messages = mergeMessages(messages + [pending])

        isSending = true
        defer { isSending = false }

        do {
            let sent = try await client.sendMessage(roomID: currentRoomID, content: trimmed, files: files)
            try repository.replacePending(clientID: clientID, with: sent)
            pendingClientIDs.remove(clientID)
            failedClientIDs.remove(clientID)
            messages = replacePendingInDisplay(clientID: clientID, with: sent)
        } catch {
            try? repository.markFailed(clientID: clientID)
            pendingClientIDs.remove(clientID)
            failedClientIDs.insert(clientID)
            errorMessage = error.localizedDescription
        }
    }

    func retrySend(clientID: String) async {
        guard failedClientIDs.contains(clientID),
              let target = messages.first(where: { $0.chatID == clientID }) else { return }
        failedClientIDs.remove(clientID)
        await sendMessage(content: target.content, files: target.files)
    }

    // MARK: - Helpers

    func isMine(_ message: ChatMessage) -> Bool {
        message.sender.userID == currentUserID
    }

    func status(of message: ChatMessage) -> ChatMessageStatus {
        if pendingClientIDs.contains(message.chatID) { return .sending }
        if failedClientIDs.contains(message.chatID) { return .failed }
        return .sent
    }

    // MARK: - Private

    private func bindSocket() {
        guard cancellables.isEmpty else { return }

        socketManager.messagePublisher
            .sink { [weak self] message in
                guard let self else { return }
                self.messages = self.mergeMessages(self.messages + [message])
                do {
                    try self.repository.saveAll([message], isRoomOpen: true)
                    try self.repository.markAllRead(roomID: self.currentRoomID)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)

        socketManager.errorPublisher
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }

    private func loadInitialLocalMessages() {
        do {
            let local = try repository.fetchLatestMessages(
                roomID: currentRoomID,
                limit: PagePolicy.initialLocalLimit
            )
            messages = local
            let pending = try repository.fetchPendingOrFailed(limit: 100)
            pendingClientIDs = Set(pending.filter { $0.status == .sending }.map(\.clientID))
            failedClientIDs = Set(pending.filter { $0.status == .failed }.map(\.clientID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncRecentMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let lastDate = try repository.lastCreatedAt(roomID: currentRoomID)

            if let lastDate {
                let cursor = DateFormatManager.shared.chatISOString(from: lastDate)
                let fresh = try await client.fetchMessages(roomID: currentRoomID, next: cursor)
                try repository.saveAll(fresh, isRoomOpen: true)
                messages = mergeMessages(messages + fresh)
            } else {
                let all = try await client.fetchMessages(roomID: currentRoomID, next: nil)
                try repository.saveAllInitial(all)
                try repository.markAllRead(roomID: currentRoomID)
                messages = mergeMessages(all)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergeMessages(_ source: [ChatMessage]) -> [ChatMessage] {
        Dictionary(grouping: source, by: \.chatID)
            .compactMap { $0.value.last }
            .sorted {
                let lhs = DateFormatManager.shared.date(fromChatISOString: $0.createdAt) ?? .distantPast
                let rhs = DateFormatManager.shared.date(fromChatISOString: $1.createdAt) ?? .distantPast
                if lhs == rhs { return $0.chatID < $1.chatID }
                return lhs < rhs
            }
    }

    private func replacePendingInDisplay(clientID: String, with sent: ChatMessage) -> [ChatMessage] {
        var next = messages.filter { $0.chatID != clientID }
        next.append(sent)
        return mergeMessages(next)
    }
}
