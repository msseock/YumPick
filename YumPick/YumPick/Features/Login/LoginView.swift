import SwiftUI

struct LoginView: View {
    var body: some View {
        ZStack {
            YPColor.backgroundPrimary.ignoresSafeArea()
            Text("로그인")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
        }
    }
}
