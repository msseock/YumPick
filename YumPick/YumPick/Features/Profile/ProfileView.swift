import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel = ProfileViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingProfileEditor = false
    #if DEBUG
    @State private var isExportingFixtures = false
    @State private var fixtureArchiveURL: URL?
    @State private var isShowingFixtureShare = false
    @State private var isShowingFixtureImporter = false
    @State private var fixtureExportMessage: String?
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                profileSection
                actionSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(YPColor.backgroundPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.fetchProfile()
        }
        .refreshable {
            await viewModel.fetchProfile()
        }
        .onChange(of: viewModel.profile) { _, profile in
            guard let profile else { return }
            authSession.updateCurrentUser(nick: profile.nick, profileImage: profile.profileImage)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                await loadAndUploadProfileImage(from: item)
                selectedPhotoItem = nil
            }
        }
        .onChange(of: viewModel.didLogout) { _, didLogout in
            if didLogout { authSession.logout() }
        }
        .sheet(isPresented: $isShowingProfileEditor) {
            profileEditorSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .sheet(isPresented: $isShowingFixtureShare) {
            if let fixtureArchiveURL {
                FixtureShareSheet(url: fixtureArchiveURL)
            }
        }
        .fileImporter(
            isPresented: $isShowingFixtureImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            importFixtureArchive(result)
        }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("마이페이지")
                .ypFont(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)

            Text("프로필 정보를 관리하고 진행 중인 채팅을 확인해요.")
                .ypFont(YPFont.body2)
                .foregroundStyle(YPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileSection: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    ZStack(alignment: .bottomTrailing) {
                        profileImage
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(YPColor.borderSubtle, lineWidth: 1))

                        ZStack {
                            Circle()
                                .fill(YPColor.actionPrimary)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(YPColor.backgroundPrimary)
                        }
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(YPColor.backgroundPrimary, lineWidth: 2))
                    }
                }
                .disabled(viewModel.isUploadingImage || viewModel.isLoading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.profile?.nick ?? "프로필을 불러오는 중")
                        .ypFont(YPFont.body1Bold)
                        .foregroundStyle(YPColor.textPrimary)
                        .lineLimit(1)

                    Text(viewModel.profile?.email ?? "이메일 정보 없음")
                        .ypFont(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                        .lineLimit(1)

                    if let phoneNum = viewModel.profile?.phoneNum, !phoneNum.isEmpty {
                        Text(phoneNum)
                            .ypFont(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                            .lineLimit(1)
                    }

                    if viewModel.isUploadingImage {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("이미지 업로드 중")
                                .ypFont(YPFont.caption1)
                                .foregroundStyle(YPColor.textTertiary)
                        }
                    }
                }

                Spacer(minLength: 28)
            }

            Button {
                isShowingProfileEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(YPColor.backgroundPrimary)
                    .frame(width: 34, height: 34)
                    .background(YPColor.actionPrimary)
                    .clipShape(Circle())
            }
            .disabled(viewModel.profile == nil || viewModel.isLoading)
            .opacity((viewModel.profile == nil || viewModel.isLoading) ? 0.45 : 1)
            .accessibilityLabel("프로필 수정")
        }
        .padding(16)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var profileImage: some View {
        if let data = viewModel.localProfileImageData,
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            CachedImage(path: viewModel.profile?.profileImage)
        }
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("프로필 정보")

            profileTextField(
                title: "닉네임",
                text: $viewModel.nick,
                prompt: "닉네임을 입력하세요"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            profileTextField(
                title: "전화번호",
                text: $viewModel.phoneNum,
                prompt: "01012345678"
            )
            .keyboardType(.phonePad)

            statusMessage

            Button {
                Task { await viewModel.saveProfile() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(YPColor.backgroundPrimary)
                    }
                    Text(viewModel.isSaving ? "저장 중" : "프로필 저장")
                        .ypFont(YPFont.body2Bold)
                }
                .foregroundStyle(YPColor.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canSave ? YPColor.actionPrimary : YPColor.gray45)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!viewModel.canSave)
        }
    }

    private var profileEditorSheet: some View {
        NavigationStack {
            ScrollView {
                editSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
            }
            .background(YPColor.backgroundPrimary)
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        isShowingProfileEditor = false
                    }
                    .ypFont(YPFont.body2Bold)
                    .foregroundStyle(YPColor.actionPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .ypFont(YPFont.caption1)
                .foregroundStyle(YPColor.semanticDanger)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let success = viewModel.successMessage {
            Text(success)
                .ypFont(YPFont.caption1)
                .foregroundStyle(YPColor.actionPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("내 활동")

            NavigationLink(value: ProfilePath.chatRooms) {
                actionRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "남아있는 채팅",
                    subtitle: "주문과 커뮤니티에서 이어진 대화를 확인해요"
                )
            }

            Button {
                Task { await viewModel.logout() }
            } label: {
                actionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: viewModel.isLoading ? "로그아웃 중" : "로그아웃",
                    subtitle: "현재 계정에서 나가기",
                    isDestructive: true
                )
            }
            .disabled(viewModel.isLoading)

            #if DEBUG
            fixtureExportSection
            #endif
        }
    }

    #if DEBUG
    private var fixtureExportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await exportFixtures() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(YPColor.actionPrimary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isExportingFixtures ? "Fixture 내보내는 중" : "Fixture 내보내기")
                            .ypFont(YPFont.body2Bold)
                            .foregroundStyle(YPColor.textPrimary)
                        Text("서버 데이터를 JSON과 미디어 ZIP으로 저장")
                            .ypFont(YPFont.caption1)
                            .foregroundStyle(YPColor.textSecondary)
                    }

                    Spacer()

                    if isExportingFixtures {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(YPColor.textTertiary)
                    }
                }
                .padding(14)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isExportingFixtures)

            Button {
                isShowingFixtureImporter = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(YPColor.actionPrimary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Fixture ZIP 불러오기")
                            .ypFont(YPFont.body2Bold)
                            .foregroundStyle(YPColor.textPrimary)
                        Text(FixtureRuntimeStore.hasActiveFixture ? "현재 불러온 fixture 사용 중" : "ZIP을 앱 안에 저장하고 바로 fixture 모드 사용")
                            .ypFont(YPFont.caption1)
                            .foregroundStyle(YPColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(YPColor.textTertiary)
                }
                .padding(14)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isExportingFixtures)

            if FixtureRuntimeStore.hasActiveFixture {
                Button {
                    clearImportedFixture()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("불러온 Fixture 제거")
                            .ypFont(YPFont.caption1)
                    }
                    .foregroundStyle(YPColor.semanticDanger)
                    .padding(.horizontal, 4)
                }
                .disabled(isExportingFixtures)
            }

            if let fixtureExportMessage {
                Text(fixtureExportMessage)
                    .ypFont(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func exportFixtures() async {
        guard !isExportingFixtures else { return }
        isExportingFixtures = true
        fixtureExportMessage = nil
        defer { isExportingFixtures = false }

        do {
            let result = try await FixtureCaptureService().capture()
            fixtureArchiveURL = result.archiveURL
            fixtureExportMessage = "완료: 성공 \(result.successCount)개, 실패 \(result.failureCount)개"
            isShowingFixtureShare = true
        } catch {
            fixtureExportMessage = "Fixture 내보내기 실패: \(error.localizedDescription)"
        }
    }

    private func importFixtureArchive(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            try FixtureRuntimeStore.importArchive(from: url)
            fixtureExportMessage = "Fixture ZIP을 불러왔습니다. 앱을 다시 실행하면 fixture 데이터가 적용됩니다."
        } catch {
            fixtureExportMessage = "Fixture 불러오기 실패: \(error.localizedDescription)"
        }
    }

    private func clearImportedFixture() {
        do {
            try FixtureRuntimeStore.clearActiveFixture()
            fixtureExportMessage = "불러온 Fixture를 제거했습니다. 앱을 다시 실행하면 서버 모드로 돌아갑니다."
        } catch {
            fixtureExportMessage = "Fixture 제거 실패: \(error.localizedDescription)"
        }
    }
    #endif

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .ypFont(YPFont.body1Bold)
            .foregroundStyle(YPColor.textPrimary)
    }

    private func profileTextField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .ypFont(YPFont.body3Bold)
                .foregroundStyle(YPColor.textSecondary)

            TextField(prompt, text: text)
                .ypFont(YPFont.body2)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(YPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(YPColor.borderSubtle, lineWidth: 1)
                )
                .disabled(viewModel.isLoading || viewModel.isSaving)
        }
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDestructive ? YPColor.semanticDanger : YPColor.actionPrimary)
                .frame(width: 32, height: 32)
                .background(isDestructive ? YPColor.semanticDanger.opacity(0.08) : YPColor.backgroundBrandSubtle)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .ypFont(YPFont.body2Bold)
                    .foregroundStyle(YPColor.textPrimary)
                Text(subtitle)
                    .ypFont(YPFont.caption1)
                    .foregroundStyle(YPColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
        .padding(14)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func loadAndUploadProfileImage(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.errorMessage = ProfileImageError.invalidImage.localizedDescription
            return
        }
        await viewModel.uploadProfileImage(data)
    }
}
