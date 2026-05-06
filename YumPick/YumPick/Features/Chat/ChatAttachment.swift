import SwiftUI
import UIKit

struct ChatAttachment: Identifiable, Equatable {
    let id: UUID
    let kind: Kind
    let data: Data
    let fileName: String
    let mimeType: String
    let thumbnail: UIImage?

    init(
        id: UUID = UUID(),
        kind: Kind,
        data: Data,
        fileName: String,
        mimeType: String,
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.kind = kind
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.thumbnail = thumbnail
    }

    enum Kind: String {
        case image
        case gif
        case video
        case pdf
    }

    var byteSize: Int { data.count }

    static func == (lhs: ChatAttachment, rhs: ChatAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

extension ChatAttachment {
    static func preview(color: UIColor = .systemGreen, fileName: String = "preview.jpg") -> ChatAttachment {
        let size = CGSize(width: 160, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return ChatAttachment(
            kind: .image,
            data: image.jpegData(compressionQuality: 0.8) ?? Data(),
            fileName: fileName,
            mimeType: "image/jpeg",
            thumbnail: image
        )
    }

    static func previewPDF(fileName: String = "document.pdf") -> ChatAttachment {
        ChatAttachment(
            kind: .pdf,
            data: Data(),
            fileName: fileName,
            mimeType: "application/pdf",
            thumbnail: nil
        )
    }
}

struct ChatAttachmentThumbnail: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(YPColor.textPrimary)
                    .background(YPColor.backgroundPrimary.clipShape(Circle()))
            }
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch attachment.kind {
        case .image, .gif, .video:
            if let thumbnail = attachment.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .overlay(alignment: .bottomLeading) { kindBadge }
            } else {
                placeholderView(systemImage: "photo")
                    .overlay(alignment: .bottomLeading) { kindBadge }
            }
        case .pdf:
            VStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(YPColor.actionAccent)
                Text(attachment.fileName)
                    .ypFont(YPFont.caption2)
                    .foregroundStyle(YPColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(YPColor.backgroundSecondary)
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch attachment.kind {
        case .gif:
            badgeText("GIF")
        case .video:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .shadow(radius: 1)
                .padding(4)
        case .image, .pdf:
            EmptyView()
        }
    }

    private func badgeText(_ text: String) -> some View {
        Text(text)
            .ypFont(YPFont.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(4)
    }

    private func placeholderView(systemImage: String) -> some View {
        ZStack {
            YPColor.backgroundSecondary
            Image(systemName: systemImage)
                .foregroundStyle(YPColor.textTertiary)
        }
    }
}

#Preview("ChatAttachmentThumbnail") {
    HStack(spacing: 12) {
        ChatAttachmentThumbnail(attachment: .preview(color: .systemGreen)) {}
        ChatAttachmentThumbnail(attachment: .previewPDF()) {}
    }
    .padding()
    .background(YPColor.backgroundPrimary)
}
