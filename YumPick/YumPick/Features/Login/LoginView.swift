import SwiftUI

struct LoginView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                titleArea

                Spacer().frame(height: 48)

                // TODO: Step 7 - 이메일 로그인 폼

                joinLink

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(YPColor.backgroundPrimary)
        }
    }

    private var titleArea: some View {
        VStack(spacing: 8) {
            Text("얌픽")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
            Text("맛있는 픽업, 지금 시작하세요")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
        }
    }

    private var joinLink: some View {
        NavigationLink {
            JoinView()
        } label: {
            Text("이메일로 회원가입")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
        }
        .padding(.top, 16)
    }
}
