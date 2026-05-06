import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachments: [ChatAttachment]
    let isSending: Bool
    let onSend: () -> Void

    @State private var showsAttachmentSheet = false
    @State private var showsMediaPicker = false
    @State private var showsGIFPicker = false
    @State private var showsDocumentPicker = false
    @State private var pdfConflictToast = false

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachment = !attachments.isEmpty
        return (hasText || hasAttachment) && !isSending
    }

    private var hasPDF: Bool {
        attachments.contains { $0.kind == .pdf }
    }

    private var remainingCount: Int {
        max(0, 5 - attachments.count)
    }

    var body: some View {
        VStack(spacing: 8) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            ChatAttachmentThumbnail(attachment: attachment) {
                                attachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.trailing, 6)
                }
            }

            if pdfConflictToast {
                Text("PDF는 단독으로만 전송할 수 있어요")
                    .ypFont(YPFont.caption1)
                    .foregroundStyle(YPColor.gray0)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(YPColor.semanticDanger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button { showsAttachmentSheet = true } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                }
                .foregroundStyle(YPColor.textSecondary)

                TextField("메시지 입력", text: $text, axis: .vertical)
                    .ypFont(YPFont.body2)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(YPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: onSend) {
                    Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .foregroundStyle(canSend ? YPColor.actionPrimary : YPColor.textTertiary)
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(YPColor.backgroundPrimary)
        // 첨부 종류 선택 시트
        .sheet(isPresented: $showsAttachmentSheet) {
            ChatAttachmentSheet { action in
                showsAttachmentSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    handleAttachmentAction(action)
                }
            }
            .presentationDetents([.height(160)])
            .presentationDragIndicator(.hidden)
        }
        // 미디어(사진/동영상) 피커
        .sheet(isPresented: $showsMediaPicker) {
            ChatAttachmentPicker(maxCount: remainingCount) { newItems in
                appendMedia(newItems)
            }
        }
        // GIF 피커 (동일 PHPicker, GIF만 필터는 아님 — 사용자가 GIF 선택)
        .sheet(isPresented: $showsGIFPicker) {
            ChatAttachmentPicker(maxCount: remainingCount) { newItems in
                appendMedia(newItems)
            }
        }
        // PDF DocumentPicker
        .sheet(isPresented: $showsDocumentPicker) {
            ChatDocumentPicker { pdfAttachment in
                attachments = [pdfAttachment]
                text = ""
            }
        }
    }

    // MARK: - Helpers

    private func handleAttachmentAction(_ action: ChatAttachmentSheetAction) {
        switch action {
        case .media:
            if hasPDF { showConflictToast(); return }
            if remainingCount > 0 { showsMediaPicker = true }
        case .gif:
            if hasPDF { showConflictToast(); return }
            if remainingCount > 0 { showsGIFPicker = true }
        case .pdf:
            if !attachments.isEmpty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showConflictToast()
                return
            }
            showsDocumentPicker = true
        }
    }

    private func appendMedia(_ newItems: [ChatAttachment]) {
        let filtered = newItems.prefix(remainingCount)
        attachments.append(contentsOf: filtered)
    }

    private func showConflictToast() {
        withAnimation(.easeInOut(duration: 0.2)) { pdfConflictToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.2)) { pdfConflictToast = false }
        }
    }
}

#Preview("ChatInputView") {
    @Previewable @State var text = "가게 앞에 도착했어요"
    @Previewable @State var attachments: [ChatAttachment] = [
        .preview(color: .systemGreen),
        .previewPDF(),
    ]

    VStack {
        Spacer()
        ChatInputView(
            text: $text,
            attachments: $attachments,
            isSending: false
        ) {}
    }
    .background(YPColor.backgroundSecondary)
}
