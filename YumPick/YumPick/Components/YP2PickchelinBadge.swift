import SwiftUI

/// 얌픽 v2.0 픽슐랭 뱃지. 흑백+옐로우 텍스트 칩.
struct YP2PickchelinBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image("Pick_Fill")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
                .foregroundStyle(YP2Color.order)

            Text("픽슐랭")
                .font(.custom("Pretendard-Bold", size: 11))
                .foregroundStyle(YP2Color.order)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(YP2Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

#Preview {
    YP2PickchelinBadge()
        .padding()
        .background(YP2Color.paper)
}
