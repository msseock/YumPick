import SwiftUI

struct TabBarView: View {
    @Environment(AuthSession.self) private var authSession

    var body: some View {
        VStack(spacing: 24) {
            Text("얌픽")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)

            Text("로그인 성공")
                .font(YPFont.body1)
                .foregroundStyle(YPColor.textSecondary)

            Button("로그아웃") {
                authSession.logout()
            }
            .font(YPFont.body2)
            .foregroundStyle(YPColor.gray0)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(YPColor.actionPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(YPColor.backgroundPrimary)
    }
}
