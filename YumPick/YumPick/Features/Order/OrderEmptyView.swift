import SwiftUI

struct OrderEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("Sesac")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundStyle(YPColor.brandDeepSprout)

                
            Text("냠픽을 시작해보세요.")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.brandDeepSprout)

            Text("건강한 픽업 생활의 시작, 냠픽")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OrderEmptyView()
        .background(YPColor.gray0)
}
