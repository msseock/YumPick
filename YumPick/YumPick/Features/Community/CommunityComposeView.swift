import SwiftUI

struct CommunityComposeView: View {
    let mode: ComposeMode
    var existingPost: PostDetail? = nil

    @State private var viewModel = CommunityComposeViewModel()
    @StateObject private var pickerVM = CommunityMediaPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 미디어 그리드
                MediaGridView(pickerVM: pickerVM, maxCount: 5)

                // 카테고리
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("카테고리", required: true)
                    TextField("예: 맛집추천", text: $viewModel.category)
                        .textFieldStyle(.plain)
                        .font(YPFont.body3)
                        .padding(12)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if viewModel.hasForbiddenCategoryChars {
                        Text(". , ? * - @ + ^ $ { } ( ) | [ ] \\ 는 사용할 수 없습니다.")
                            .font(YPFont.caption2)
                            .foregroundStyle(.red)
                    }
                }

                // 제목
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("제목", required: true)
                    TextField("제목을 입력하세요", text: $viewModel.title)
                        .textFieldStyle(.plain)
                        .font(YPFont.body3)
                        .padding(12)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // 본문
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("내용", required: true)
                    TextField("내용을 입력하세요", text: $viewModel.content, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(YPFont.body3)
                        .lineLimit(5...12)
                        .padding(12)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // 가게 ID (임시)
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("가게 ID (선택)", required: false)
                    TextField("가게 ID를 입력하세요", text: $viewModel.storeId)
                        .textFieldStyle(.plain)
                        .font(YPFont.body3)
                        .padding(12)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(YPFont.caption1)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = pickerVM.errorMessage {
                    Text(error)
                        .font(YPFont.caption1)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
                    .foregroundStyle(YPColor.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                submitButton
            }
        }
        .onAppear {
            viewModel.configure(for: mode, existing: existingPost)
        }
        .onChange(of: viewModel.didSubmit) { _, submitted in
            if submitted { dismiss() }
        }
    }

    private var submitButton: some View {
        Group {
            if viewModel.isSubmitting || pickerVM.isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("완료") {
                    Task { await viewModel.submit(mediaItems: pickerVM.mediaItems) }
                }
                .font(YPFont.body3Bold)
                .foregroundStyle(viewModel.canSubmit ? YPColor.actionAccent : YPColor.textTertiary)
                .disabled(!viewModel.canSubmit)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "게시글 작성"
        case .edit: return "게시글 수정"
        }
    }

    private func fieldLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(YPFont.body3Bold)
                .foregroundStyle(YPColor.textPrimary)
            if required {
                Text("*")
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.actionAccent)
            }
        }
    }
}
