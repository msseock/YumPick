import Combine
import Foundation
import Network

@MainActor
final class ChatOutboxWorker {
    struct SentMessage {
        let clientID: String
        let message: ChatMessage
    }

    static let shared = ChatOutboxWorker()

    private let sentMessageSubject = PassthroughSubject<SentMessage, Never>()
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "chat.outbox.monitor")
    private var isRunning = false
    private var isFlushing = false

    private let repository: ChatRealmRepositoryProtocol
    private let client: ChatClientProtocol

    init(
        repository: ChatRealmRepositoryProtocol = ChatRealmRepository(),
        client: ChatClientProtocol = ChatClient()
    ) {
        self.repository = repository
        self.client = client
    }

    var sentMessagePublisher: AnyPublisher<SentMessage, Never> {
        sentMessageSubject.eraseToAnyPublisher()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in await self?.flush() }
        }
        monitor.start(queue: monitorQueue)
        Task { await flush() }
    }

    func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        do {
            let queued = try repository.fetchPendingOrFailed(limit: 20)
            for item in queued {
                do {
                    let sent = try await client.sendMessage(
                        roomID: item.roomID,
                        content: item.content,
                        files: item.files
                    )
                    await MainActor.run {
                        ChatUserDirectory.shared.upsert(sent.sender)
                    }
                    try repository.replacePending(clientID: item.clientID, with: sent)
                    sentMessageSubject.send(SentMessage(clientID: item.clientID, message: sent))
                } catch {
                    try? repository.markFailed(clientID: item.clientID)
                    break
                }
            }
        } catch {
            // 로깅만
        }
    }
}
