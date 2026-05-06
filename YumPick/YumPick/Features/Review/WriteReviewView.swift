import SwiftUI
import PhotosUI

struct WriteReviewView: View {
    @State private var viewModel: WriteReviewViewModel
    @Environment(\.dismiss) private var dismiss
    var onSuccess: (() -> Void)?

    init(mode: ReviewMode, onSuccess: (() -> Void)? = nil) {
        _viewModel = State(initialValue: WriteReviewViewModel(mode: mode))
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    formContent
                }
            }
            .navigationTitle(viewModel.isEditMode ? "리뷰 수정" : "리뷰 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(YPColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("등록") {
                        Task { await viewModel.submit() }
                    }
                    .font(YPFont.body1Bold)
                    .foregroundStyle(viewModel.isSubmitting ? YPColor.textTertiary : YPColor.brandBlackSprout)
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
        .task { await viewModel.loadIfEditing() }
        .onChange(of: viewModel.selectedItems) {
            Task { await viewModel.loadSelectedImages() }
        }
        .onChange(of: viewModel.isSuccess) { _, newValue in
            if newValue {
                onSuccess?()
                dismiss()
            }
        }
        .alert("오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ratingSection
                YPDivider()
                contentSection
                YPDivider()
                imageSection
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("별점")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    Button {
                        viewModel.rating = star
                    } label: {
                        Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundStyle(star <= viewModel.rating ? YPColor.brandBrightForsythia : YPColor.backgroundSecondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("리뷰 내용")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.textPrimary)
                .padding(.horizontal, 20)

            ZStack(alignment: .topLeading) {
                if viewModel.content.isEmpty {
                    Text("음식은 어떠셨나요? 솔직한 리뷰를 남겨주세요.")
                        .font(YPFont.body2)
                        .foregroundStyle(YPColor.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                TextEditor(text: $viewModel.content)
                    .font(YPFont.body2)
                    .foregroundStyle(YPColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(YPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("사진 첨부")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
                Text("(\(viewModel.existingImageURLs.count + viewModel.selectedImages.count)/5)")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textTertiary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let totalCount = viewModel.existingImageURLs.count + viewModel.selectedImages.count
                    if totalCount < 5 {
                        PhotosPicker(
                            selection: $viewModel.selectedItems,
                            maxSelectionCount: 5 - totalCount,
                            matching: .images
                        ) {
                            addImageButton
                        }
                    }

                    ForEach(Array(viewModel.existingImageURLs.enumerated()), id: \.offset) { index, url in
                        imageThumb {
                            CachedImage(path: url)
                                .scaledToFill()
                        } onRemove: {
                            viewModel.removeExistingImage(at: index)
                        }
                    }

                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { _, image in
                        imageThumb {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } onRemove: {
                            if let idx = viewModel.selectedImages.firstIndex(of: image) {
                                viewModel.selectedImages.remove(at: idx)
                                if idx < viewModel.selectedItems.count {
                                    viewModel.selectedItems.remove(at: idx)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var addImageButton: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(YPColor.borderSubtle, lineWidth: 1)
            .frame(width: 80, height: 80)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                    Text("사진 추가")
                        .font(YPFont.caption1)
                }
                .foregroundStyle(YPColor.textTertiary)
            }
    }

    private func imageThumb<Content: View>(
        @ViewBuilder content: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    WriteReviewView(mode: .create(storeId: "mock-store-id", orderCode: "A1234"))
}
