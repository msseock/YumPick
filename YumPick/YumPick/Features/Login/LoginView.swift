import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                titleArea

                Spacer().frame(height: 48)

                loginForm

                Spacer().frame(height: 16)

                loginButton

                appleLoginButton

                joinLink

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(YPColor.backgroundPrimary)
        }
        .alert("로그인 오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
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

    private var loginForm: some View {
        VStack(spacing: 12) {
            TextField("이메일", text: $viewModel.email)
                .font(YPFont.body1)
                .tint(YPColor.actionPrimary)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .padding(12)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            SecureField("비밀번호", text: $viewModel.password)
                .font(YPFont.body1)
                .textContentType(.password)
                .padding(12)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var loginButton: some View {
        Button {
            Task {
                if let tokens = await viewModel.loginTapped() {
                    authSession.login(tokens: tokens)
                }
            }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(YPColor.gray0)
                } else {
                    Text("이메일로 로그인")
                        .font(YPFont.body1)
                        .foregroundStyle(YPColor.gray0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(viewModel.canSubmit ? YPColor.actionPrimary : YPColor.gray45)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.canSubmit || viewModel.isLoading)
    }

    private var appleLoginButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            Task {
                if let tokens = await viewModel.handleAppleLoginResult(result) {
                    authSession.login(tokens: tokens)
                }
            }
        }
        .frame(height: 52)
        .signInWithAppleButtonStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
        .disabled(viewModel.isLoading)
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
