import SwiftUI

struct JoinView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel = JoinViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                emailSection
                passwordSection
                passwordConfirmSection
                nickSection
                submitButton
            }
            .padding(24)
        }
        .background(YPColor.backgroundPrimary)
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Email

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이메일")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)

            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if viewModel.email.isEmpty {
                        Text("example@email.com")
                            .font(YPFont.body1)
                            .foregroundStyle(YPColor.actionPrimary)
                            .padding(.horizontal, 12)
                    }

                    TextField("", text: $viewModel.email)
                        .font(YPFont.body1)
                        .tint(YPColor.actionPrimary)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .padding(12)
                }
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    Task { await viewModel.checkEmailTapped() }
                } label: {
                    Group {
                        if viewModel.emailCheckState == .loading {
                            ProgressView().tint(YPColor.gray0)
                        } else {
                            Text("중복확인")
                                .font(YPFont.body2)
                                .foregroundStyle(YPColor.gray0)
                        }
                    }
                    .frame(width: 72, height: 44)
                    .background(viewModel.canCheckEmail ? YPColor.actionPrimary : YPColor.gray45)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!viewModel.canCheckEmail || viewModel.emailCheckState == .loading)
            }

            emailStatusText
        }
    }

    @ViewBuilder
    private var emailStatusText: some View {
        switch viewModel.emailCheckState {
        case .available:
            Text("사용 가능한 이메일입니다").font(YPFont.caption1).foregroundStyle(.green)
        case .duplicated:
            Text("이미 사용 중인 이메일입니다").font(YPFont.caption1).foregroundStyle(.red)
        case .invalid:
            Text("이메일 확인에 실패했습니다").font(YPFont.caption1).foregroundStyle(.red)
        default:
            if let err = viewModel.emailError {
                Text(err).font(YPFont.caption1).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Password

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("비밀번호")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)

            SecureField("8자 이상, 영문·숫자·특수문자 포함", text: $viewModel.password)
                .font(YPFont.body1)
                .textContentType(.newPassword)
                .padding(12)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = viewModel.passwordError {
                Text(err).font(YPFont.caption1).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Password Confirm

    private var passwordConfirmSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("비밀번호 확인")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)

            SecureField("비밀번호를 다시 입력해주세요", text: $viewModel.passwordConfirm)
                .font(YPFont.body1)
                .textContentType(.newPassword)
                .padding(12)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = viewModel.passwordConfirmError {
                Text(err).font(YPFont.caption1).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Nick

    private var nickSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("닉네임")
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)

            TextField("닉네임을 입력해주세요", text: $viewModel.nick)
                .font(YPFont.body1)
                .autocapitalization(.none)
                .padding(12)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let err = viewModel.nickError {
                Text(err).font(YPFont.caption1).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task {
                if let tokens = await viewModel.submitTapped() {
                    authSession.login(tokens: tokens)
                }
            }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(YPColor.gray0)
                } else {
                    Text("가입하기")
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
        .padding(.top, 8)
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
