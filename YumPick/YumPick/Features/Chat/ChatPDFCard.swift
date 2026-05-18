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
                    RoundedRectangle(cornerRadius: 6)
                        .fill(YP2Color.actionPrimary.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(YP2Color.actionInk)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.custom("Pretendard-Medium", size: 14))
                        .foregroundStyle(YP2Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("PDF")
                        .font(.custom("Pretendard-Medium", size: 11))
                        .foregroundStyle(Color(hex: "#999999"))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#999999"))
            }
            .padding(12)
            .frame(width: 224)
            .background(YP2Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
