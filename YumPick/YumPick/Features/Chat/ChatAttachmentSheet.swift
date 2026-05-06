import SwiftUI

enum ChatAttachmentSheetAction {
    case media
    case gif
    case pdf
}

struct ChatAttachmentSheet: View {
    let onSelect: (ChatAttachmentSheetAction) -> Void

    private let items: [(action: ChatAttachmentSheetAction, icon: String, label: String)] = [
        (.media, "photo.on.rectangle", "사진/동영상"),
        (.gif,   "play.square",        "GIF"),
        (.pdf,   "doc.fill",           "PDF 파일"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(YPColor.gray30)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            HStack(spacing: 24) {
                ForEach(items, id: \.label) { item in
                    Button {
                        onSelect(item.action)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(YPColor.backgroundSecondary)
                                    .frame(width: 60, height: 60)
                                Image(systemName: item.icon)
                                    .font(.system(size: 24))
                                    .foregroundStyle(
                                        item.action == .pdf
                                        ? YPColor.actionAccent
                                        : YPColor.actionPrimary
                                    )
                            }
                            Text(item.label)
                                .ypFont(YPFont.caption1)
                                .foregroundStyle(YPColor.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(YPColor.backgroundPrimary)
    }
}

#Preview {
    ChatAttachmentSheet { _ in }
        .background(YPColor.backgroundPrimary)
}
