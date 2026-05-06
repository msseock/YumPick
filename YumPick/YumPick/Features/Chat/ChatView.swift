import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var attachedAssets: [ChatAttachment] = []
    @State private var isAtBottom: Bool = true
    @State private var isUploading: Bool = false
    @Namespace private var mediaNamespace
    @State private var lightboxFiles: [String] = []
    @State private var lightboxIndex: Int? = nil
    @State private var pdfViewerPath: String? = nil
    @State private var deletionConfirmation: ChatMessageDeletionConfirmation?
    @Environment(\.scenePhase) private var scenePhase

    private var isLightboxActive: Bool { lightboxIndex != nil }

    init(roomID: String) {
        _viewModel = State(initialValue: ChatViewModel(roomID: roomID))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                if shouldShowDateDivider(at: index) {
                                    ChatDateDivider(isoString: message.createdAt)
                                }
                                ChatBubbleView(
                                    message: message,
                                    isMine: viewModel.isMine(message),
                                    status: viewModel.status(of: message),
                                    namespace: mediaNamespace,
                                    onRetry: { Task { await viewModel.retrySend(clientID: message.chatID) } },
                                    onDelete: {
                                        deletionConfirmation = .deleteLocal(message)
                                    },
                                    onCancelFailedSend: {
                                        deletionConfirmation = .cancelFailedSend(message)
                                    },
                                    onImageTapped: { index in
                                        let mediaFiles = message.files.splitMediaAndPDF().media
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            lightboxFiles = mediaFiles
                                            lightboxIndex = index
                                        }
                                    },
                                    onPDFTapped: { path in
                                        pdfViewerPath = path
                                    }
                                )
                                .id(message.id)
                                .onAppear {
                                    viewModel.loadOlderMessagesIfNeeded(current: message)
                                }
                            }
                            Color.clear.frame(height: 1).id("__bottom__")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(YPColor.backgroundPrimary)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.last?.id) { _, id in
                        guard let id, isAtBottom || isMineLastMessage() else { return }
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                    .onAppear {
                        proxy.scrollTo("__bottom__", anchor: .bottom)
                    }
                }

                if let error = viewModel.errorMessage {
                    ChatErrorBanner(message: error) { viewModel.errorMessage = nil }
                }

                if isUploading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("파일 업로드 중...")
                            .ypFont(YPFont.caption1)
                            .foregroundStyle(YPColor.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(YPColor.backgroundSecondary)
                }

                ChatInputView(
                    text: $inputText,
                    attachments: $attachedAssets,
                    isSending: viewModel.isSending,
                    onSend: send
                )
            }
            .background(YPColor.backgroundPrimary)

            if isLightboxActive {
                MediaLightboxView(
                    files: lightboxFiles,
                    selectedIndex: $lightboxIndex,
                    namespace: mediaNamespace
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .toolbar(isLightboxActive ? .hidden : .visible, for: .navigationBar)
        .alert(
            deletionConfirmation?.title ?? "",
            isPresented: Binding(
                get: { deletionConfirmation != nil },
                set: { if !$0 { deletionConfirmation = nil } }
            ),
            presenting: deletionConfirmation
        ) { confirmation in
            Button(confirmation.confirmTitle, role: .destructive) {
                switch confirmation.kind {
                case .deleteLocal:
                    viewModel.deleteLocalMessage(confirmation.message)
                case .cancelFailedSend:
                    viewModel.cancelFailedSend(clientID: confirmation.message.chatID)
                }
                deletionConfirmation = nil
            }
            Button("취소", role: .cancel) {
                deletionConfirmation = nil
            }
        } message: { confirmation in
            Text(confirmation.messageText)
        }
        .fullScreenCover(
            isPresented: Binding(get: { pdfViewerPath != nil }, set: { if !$0 { pdfViewerPath = nil } })
        ) {
            if let path = pdfViewerPath {
                PDFViewerView(path: path) { pdfViewerPath = nil }
            }
        }
        .task {
            ChatPushHandler.shared.currentOpenRoomID = viewModel.currentRoomID
            viewModel.onAppear()
        }
        .onDisappear {
            ChatPushHandler.shared.currentOpenRoomID = nil
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:     viewModel.onAppear()
            case .background: viewModel.onDisappear()
            default:          break
            }
        }
    }

    // MARK: - Actions

    private func send() {
        let content = inputText
        let assets = attachedAssets
        inputText = ""
        attachedAssets = []

        Task {
            let paths: [String]
            if assets.isEmpty {
                paths = []
            } else {
                isUploading = true
                paths = await uploadAttachments(assets)
                isUploading = false
            }
            await viewModel.sendMessage(content: content, files: paths)
            isAtBottom = true
        }
    }

    private func uploadAttachments(_ assets: [ChatAttachment]) async -> [String] {
        let parts = assets.map { asset in
            MultipartData(
                name: "files",
                fileName: asset.fileName,
                mimeType: asset.mimeType,
                data: asset.data
            )
        }
        do {
            let paths = try await ChatClient().uploadFiles(roomID: viewModel.currentRoomID, parts: parts)
            for (asset, path) in zip(assets, paths) where asset.kind == .pdf {
                ChatFileNameCache.shared.set(path: path, originalName: asset.fileName)
            }
            return paths
        } catch {
            await MainActor.run { viewModel.errorMessage = "파일 업로드에 실패했습니다." }
            return []
        }
    }

    // MARK: - Helpers

    private func shouldShowDateDivider(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index]
        let previous = viewModel.messages[index - 1]
        guard
            let currentDate = DateFormatManager.shared.date(fromChatISOString: current.createdAt),
            let previousDate = DateFormatManager.shared.date(fromChatISOString: previous.createdAt)
        else { return false }
        return !Calendar.current.isDate(currentDate, inSameDayAs: previousDate)
    }

    private func isMineLastMessage() -> Bool {
        viewModel.messages.last.map(viewModel.isMine) ?? false
    }
}

// MARK: - Supporting Views

private struct ChatMessageDeletionConfirmation: Identifiable {
    enum Kind {
        case deleteLocal
        case cancelFailedSend
    }

    let id = UUID()
    let kind: Kind
    let message: ChatMessage

    static func deleteLocal(_ message: ChatMessage) -> ChatMessageDeletionConfirmation {
        ChatMessageDeletionConfirmation(kind: .deleteLocal, message: message)
    }

    static func cancelFailedSend(_ message: ChatMessage) -> ChatMessageDeletionConfirmation {
        ChatMessageDeletionConfirmation(kind: .cancelFailedSend, message: message)
    }

    var title: String {
        switch kind {
        case .deleteLocal:
            return "메시지 삭제"
        case .cancelFailedSend:
            return "전송 취소"
        }
    }

    var confirmTitle: String {
        switch kind {
        case .deleteLocal:
            return "삭제"
        case .cancelFailedSend:
            return "전송 취소"
        }
    }

    var messageText: String {
        switch kind {
        case .deleteLocal:
            return "이 메시지는 서버에서 삭제되지 않고 이 기기에서만 안 보이게 삭제됩니다."
        case .cancelFailedSend:
            return "전송 실패한 메시지를 취소하고 이 기기에서 삭제합니다."
        }
    }
}

struct ChatDateDivider: View {
    let isoString: String

    var body: some View {
        if let date = DateFormatManager.shared.date(fromChatISOString: isoString) {
            HStack {
                Rectangle().frame(height: 1).foregroundStyle(YPColor.gray15)
                Text(DateFormatManager.shared.chatDateLabel(from: date))
                    .ypFont(YPFont.caption2)
                    .foregroundStyle(YPColor.textTertiary)
                    .fixedSize()
                Rectangle().frame(height: 1).foregroundStyle(YPColor.gray15)
            }
            .padding(.vertical, 8)
        }
    }
}

struct ChatErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .ypFont(YPFont.caption1)
                .foregroundStyle(YPColor.gray0)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(YPColor.gray0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(YPColor.semanticDanger)
    }
}
