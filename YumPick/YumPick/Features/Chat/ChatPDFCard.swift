import SwiftUI

struct ChatPDFCard: View {
    let path: String
    let onTap: () -> Void

    private var displayName: String {
        ChatFileNameCache.shared.displayName(for: path)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(YPColor.actionAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(YPColor.actionAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .ypFont(YPFont.body2)
                        .foregroundStyle(YPColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("PDF")
                        .ypFont(YPFont.caption2)
                        .foregroundStyle(YPColor.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(YPColor.textTertiary)
            }
            .padding(12)
            .frame(width: 224)
            .background(YPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatPDFCard(path: "/data/chat/document.pdf") {}
        ChatPDFCard(path: "/data/chat/very-long-file-name-that-wraps.pdf") {}
    }
    .padding()
    .background(YPColor.backgroundPrimary)
}
