import Combine
import Foundation
import SocketIO

// MARK: - Protocol

protocol ChatSocketManagerProtocol {
    var messagePublisher: AnyPublisher<ChatMessage, Never> { get }
    var errorPublisher: AnyPublisher<Error, Never> { get }

    func connect(roomID: String)
    func disconnect()
}

// MARK: - Implementation

final class ChatSocketManager: ChatSocketManagerProtocol {
    private let keychain: KeychainManager
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var currentRoomID: String?
    private var reconnectAttempt: Int = 0
    private var didRefreshTokenForCurrentSession: Bool = false
    private var reconnectTask: Task<Void, Never>?
    private var connectionGeneration: Int = 0

    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()

    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }

    init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
    }

    func connect(roomID: String) {
        print("소켓 연결")
        closeSocket(clearRoom: false)
        currentRoomID = roomID
        reconnectAttempt = 0
        didRefreshTokenForCurrentSession = false
        connectionGeneration += 1
        openSocket(roomID: roomID, generation: connectionGeneration)
    }

    func disconnect() {
        print("소켓 연결 해제")
        closeSocket(clearRoom: true)
    }

    // MARK: - Private

    private func closeSocket(clearRoom: Bool) {
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionGeneration += 1
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager = nil
        if clearRoom {
            currentRoomID = nil
        }
    }

    private func openSocket(roomID: String, generation: Int) {
        guard generation == connectionGeneration else { return }
        guard let url = URL(string: SecretConstants.baseURL) else {
            errorSubject.send(NetworkError.invalidURL)
            return
        }

        var extraHeaders = ["SeSACKey": SecretConstants.sesacKey]
        if let accessToken = keychain.read(key: .accessToken) {
            extraHeaders["Authorization"] = accessToken
        }

        manager = SocketManager(
            socketURL: url,
            config: [
                .path("/chats-\(roomID)"),
                .extraHeaders(extraHeaders),
                .log(false),
                .compress,
                .reconnects(false),
                .forceWebsockets(true)
            ]
        )
        socket = manager?.defaultSocket
        attachHandlers(roomID: roomID, generation: generation)
        socket?.connect()
    }

    private func attachHandlers(roomID: String, generation: Int) {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            guard self?.connectionGeneration == generation else { return }
            self?.reconnectAttempt = 0
        }

        socket?.on("chat") { [weak self] dataArray, _ in
            guard let self, self.connectionGeneration == generation, let payload = dataArray.first else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                let message = try JSONDecoder().decode(ChatMessage.self, from: data)
                self.messageSubject.send(message)
            } catch {
                self.errorSubject.send(error)
            }
        }

        socket?.on(clientEvent: .error) { [weak self] data, _ in
            self?.handleSocketError(data: data, roomID: roomID, generation: generation)
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.scheduleReconnectIfNeeded(generation: generation)
        }
    }

    private func handleSocketError(data: [Any], roomID: String, generation: Int) {
        guard generation == connectionGeneration else { return }
        let description = data.map { "\($0)" }.joined(separator: " ")
        let isAuth = description.contains("401") || description.lowercased().contains("unauthorized")

        if isAuth, !didRefreshTokenForCurrentSession {
            didRefreshTokenForCurrentSession = true
            Task { [weak self] in
                do {
                    try await NetworkManager.shared.refreshAuthorization()
                    self?.closeSocket(clearRoom: false)
                    guard let generation = self?.connectionGeneration else { return }
                    self?.openSocket(roomID: roomID, generation: generation)
                } catch {
                    self?.errorSubject.send(error)
                }
            }
            return
        }

        errorSubject.send(NetworkError.unknown)
        scheduleReconnectIfNeeded(generation: generation)
    }

    private func scheduleReconnectIfNeeded(generation: Int) {
        guard generation == connectionGeneration else { return }
        guard let roomID = currentRoomID else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            guard let self,
                  self.connectionGeneration == generation,
                  self.currentRoomID == roomID else { return }
            self.openSocket(roomID: roomID, generation: generation)
        }
    }
}
