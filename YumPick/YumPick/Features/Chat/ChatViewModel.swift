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
    private(set) var hasMoreOlder: Bool = true
    private(set) var pendingOlderAnchorID: String?
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
        client: ChatClientProtocol = FixtureClientFactory.chatClient(),
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
        if !FixtureFileResolver.usesFixtures {
            loadInitialLocalMessages()
        }
        socketManager.connect(roomID: currentRoomID)
        Task { await syncRecentMessages() }
        outbox.start()
    }

    func onDisappear() {
        isAppeared = false
        socketManager.disconnect()
        cancellables.removeAll()
    }

    func resyncOnNetworkRecovery() async {
        guard isAppeared else { return }
        socketManager.connect(roomID: currentRoomID)
        await syncRecentMessages()
    }

    // MARK: - Pagination

    func loadOlderMessagesIfNeeded(current message: ChatMessage) {
        guard hasMoreOlder, !isLoadingOlder else { return }
        guard message.id == messages.first?.id else { return }
        Task { await loadOlderMessages() }
    }

    func loadOlderMessages() async {
        guard hasMoreOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            guard let oldestDate = DateFormatManager.shared.date(fromChatISOString: oldest.createdAt) else { return }
            let older = try repository.fetchMessagesBefore(
                roomID: currentRoomID,
                before: oldestDate,
                limit: PagePolicy.olderPageSize
            )
            if older.isEmpty {
                hasMoreOlder = false
                return
            }
            let anchorID = oldest.id
            prependOlderMessages(older)
            pendingOlderAnchorID = anchorID
            if older.count < PagePolicy.olderPageSize {
                hasMoreOlder = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func consumePendingOlderAnchorID(_ id: String) {
        guard pendingOlderAnchorID == id else { return }
        pendingOlderAnchorID = nil
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
            ChatUserDirectory.shared.upsert(sent.sender)
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

    func deleteLocalMessage(_ message: ChatMessage) {
        do {
            try repository.deleteMessage(chatID: message.chatID)
            pendingClientIDs.remove(message.chatID)
            failedClientIDs.remove(message.chatID)
            messages.removeAll { $0.chatID == message.chatID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelFailedSend(clientID: String) {
        guard failedClientIDs.contains(clientID) else { return }
        do {
            try repository.deletePendingOrFailed(clientID: clientID)
            pendingClientIDs.remove(clientID)
            failedClientIDs.remove(clientID)
            messages.removeAll { $0.chatID == clientID }
        } catch {
            errorMessage = error.localizedDescription
        }
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self else { return }
                guard message.roomID == self.currentRoomID else { return }
                ChatUserDirectory.shared.upsert(message.sender)
                do {
                    if let pendingClientID = self.matchingPendingClientID(for: message) {
                        try self.repository.replacePending(clientID: pendingClientID, with: message)
                        self.pendingClientIDs.remove(pendingClientID)
                        self.failedClientIDs.remove(pendingClientID)
                        self.messages = self.replacePendingInDisplay(clientID: pendingClientID, with: message)
                    } else {
                        self.appendMessages([message])
                        try self.repository.saveAll([message], isRoomOpen: true)
                    }
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

        outbox.sentMessagePublisher
            .sink { [weak self] sent in
                guard let self, sent.message.roomID == self.currentRoomID else { return }
                self.pendingClientIDs.remove(sent.clientID)
                self.failedClientIDs.remove(sent.clientID)
                self.messages = self.replacePendingInDisplay(clientID: sent.clientID, with: sent.message)
            }
            .store(in: &cancellables)
    }

    private func loadInitialLocalMessages() {
        do {
            let pending = try repository.fetchPendingOrFailed(limit: 100)
            pendingClientIDs = Set(pending.filter { $0.status == .sending }.map(\.clientID))
            failedClientIDs = Set(pending.filter { $0.status == .failed }.map(\.clientID))

            guard messages.isEmpty else { return }

            let local = try repository.fetchLatestMessages(
                roomID: currentRoomID,
                limit: PagePolicy.initialLocalLimit
            )
            messages = local
            hasMoreOlder = local.count == PagePolicy.initialLocalLimit
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func syncRecentMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if FixtureFileResolver.usesFixtures {
                try await syncFixtureMessages()
                return
            }

            let lastDate = try repository.lastCreatedAt(roomID: currentRoomID)

            if let lastDate {
                let cursor = DateFormatManager.shared.chatISOString(from: lastDate)
                let fresh = try await client.fetchMessages(roomID: currentRoomID, next: cursor)
                ChatUserDirectory.shared.upsert(fresh.map(\.sender))
                try repository.saveAll(fresh, isRoomOpen: true)
                if !fresh.isEmpty {
                    appendMessages(fresh)
                }
            } else {
                let all = try await client.fetchMessages(roomID: currentRoomID, next: nil)
                ChatUserDirectory.shared.upsert(all.map(\.sender))
                try repository.saveAllInitial(all)
                let latest = try repository.fetchLatestMessages(
                    roomID: currentRoomID,
                    limit: PagePolicy.initialLocalLimit
                )
                messages = mergeMessages(messages + latest)
                hasMoreOlder = latest.count == PagePolicy.initialLocalLimit
            }

            try repository.markAllRead(roomID: currentRoomID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncFixtureMessages() async throws {
        let fixtureMessages = try await client.fetchMessages(roomID: currentRoomID, next: nil)
        let pending = try repository.fetchPendingOrFailed(limit: 100)
        pendingClientIDs = Set(pending.filter { $0.status == .sending }.map(\.clientID))
        failedClientIDs = Set(pending.filter { $0.status == .failed }.map(\.clientID))

        ChatUserDirectory.shared.upsert(fixtureMessages.map(\.sender))
        try repository.saveAllInitial(fixtureMessages)

        let localPendingMessages = try repository.fetchLatestMessages(
            roomID: currentRoomID,
            limit: PagePolicy.initialLocalLimit
        )
        .filter { pendingClientIDs.contains($0.chatID) || failedClientIDs.contains($0.chatID) }

        messages = mergeMessages(fixtureMessages + localPendingMessages)
        hasMoreOlder = false
        try repository.markAllRead(roomID: currentRoomID)
    }

    private func appendMessages(_ newMessages: [ChatMessage]) {
        let roomMessages = newMessages.filter { $0.roomID == currentRoomID }
        guard !roomMessages.isEmpty else { return }
        messages = mergeMessages(messages + roomMessages)
    }

    private func prependOlderMessages(_ olderMessages: [ChatMessage]) {
        let roomMessages = olderMessages.filter { $0.roomID == currentRoomID }
        guard !roomMessages.isEmpty else { return }
        messages = mergeMessages(roomMessages + messages)
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

    private func matchingPendingClientID(for message: ChatMessage) -> String? {
        guard let currentUserID, message.sender.userID == currentUserID else { return nil }
        return messages.first { candidate in
            pendingClientIDs.contains(candidate.chatID)
                && candidate.sender.userID == message.sender.userID
                && candidate.content == message.content
                && candidate.files == message.files
        }?.chatID
    }

    private func replacePendingInDisplay(clientID: String, with sent: ChatMessage) -> [ChatMessage] {
        var next = messages.filter { $0.chatID != clientID }
        next.append(sent)
        return mergeMessages(next)
    }
}
