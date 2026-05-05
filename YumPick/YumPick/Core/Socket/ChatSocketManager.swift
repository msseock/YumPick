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

    private let messageSubject = PassthroughSubject<ChatMessage, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()

    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
    }

    func connect(roomID: String) {
        disconnect()
        currentRoomID = roomID
        reconnectAttempt = 0
        didRefreshTokenForCurrentSession = false
        openSocket(roomID: roomID)
    }

    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        socket = nil
        manager = nil
        currentRoomID = nil
    }

    // MARK: - Private

    private func openSocket(roomID: String) {
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
                .reconnects(false)
            ]
        )
        socket = manager?.defaultSocket
        attachHandlers(roomID: roomID)
        socket?.connect()
    }

    private func attachHandlers(roomID: String) {
        socket?.on(clientEvent: .connect) { [weak self] _, _ in
            self?.reconnectAttempt = 0
        }

        socket?.on("chat") { [weak self] dataArray, _ in
            guard let self, let payload = dataArray.first else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: payload)
                let message = try JSONDecoder().decode(ChatMessage.self, from: data)
                self.messageSubject.send(message)
            } catch {
                self.errorSubject.send(error)
            }
        }

        socket?.on(clientEvent: .error) { [weak self] data, _ in
            self?.handleSocketError(data: data, roomID: roomID)
        }

        socket?.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.scheduleReconnectIfNeeded()
        }
    }

    private func handleSocketError(data: [Any], roomID: String) {
        let description = data.map { "\($0)" }.joined(separator: " ")
        let isAuth = description.contains("401") || description.lowercased().contains("unauthorized")

        if isAuth, !didRefreshTokenForCurrentSession {
            didRefreshTokenForCurrentSession = true
            Task { [weak self] in
                do {
                    try await NetworkManager.shared.refreshAuthorization()
                    self?.openSocket(roomID: roomID)
                } catch {
                    self?.errorSubject.send(error)
                }
            }
            return
        }

        errorSubject.send(NetworkError.unknown)
        scheduleReconnectIfNeeded()
    }

    private func scheduleReconnectIfNeeded() {
        guard let roomID = currentRoomID else { return }
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.currentRoomID == roomID else { return }
            self.openSocket(roomID: roomID)
        }
    }
}
