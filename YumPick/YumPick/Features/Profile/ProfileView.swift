import SwiftUI

struct ProfileView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("마이페이지")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)

            Button("로그아웃") {
                Task { await viewModel.logout() }
            }
            .font(YPFont.body2)
            .foregroundStyle(YPColor.backgroundPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(viewModel.isLoading ? YPColor.actionPrimary.opacity(0.5) : YPColor.actionPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(viewModel.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.didLogout) { _, didLogout in
            if didLogout { authSession.logout() }
        }
    }
}
