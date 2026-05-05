import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    @Binding var attachments: [ChatAttachment]
    let isSending: Bool
    let onSend: () -> Void
    @State private var showsPicker = false

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && !isSending
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

            HStack(alignment: .bottom, spacing: 8) {
                Button { showsPicker = true } label: {
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
        .sheet(isPresented: $showsPicker) {
            ChatAttachmentPicker(maxCount: 5 - attachments.count) { newItems in
                attachments.append(contentsOf: newItems)
            }
        }
    }
}

#Preview("ChatInputView") {
    @Previewable @State var text = "가게 앞에 도착했어요"
    @Previewable @State var attachments: [ChatAttachment] = [
        .preview(color: .systemGreen),
        .preview(color: .systemOrange)
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
