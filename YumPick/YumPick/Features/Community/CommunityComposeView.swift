import SwiftUI

struct CommunityComposeView: View {
    let mode: ComposeMode
    var existingPost: PostDetail? = nil

    @State private var viewModel = CommunityComposeViewModel()
    @State private var storePickerVM = CommunityStorePickerViewModel()
    @StateObject private var pickerVM = CommunityMediaPickerViewModel()
    @State private var isStorePickerPresented = false
    @State private var didConfigure = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                composeHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 24) {
                    ComposeSection(title: "사진/영상", caption: "최대 5개까지 첨부할 수 있어요") {
                        MediaGridView(pickerVM: pickerVM, maxCount: 5)
                    }

                    ComposeSection(title: "카테고리", required: true, caption: "특수문자 없이 짧게 입력해 주세요") {
                        formTextField("예: 맛집추천", text: $viewModel.category)

                        if viewModel.hasForbiddenCategoryChars {
                            validationText(". , ? * - @ + ^ $ { } ( ) | [ ] \\ 는 사용할 수 없습니다.")
                        }
                    }

                    ComposeSection(title: "제목", required: true) {
                        formTextField("제목을 입력하세요", text: $viewModel.title)
                    }

                    ComposeSection(title: "내용", required: true) {
                        formEditor(placeholder: "픽업한 음식과 가게 경험을 자세히 적어주세요.")
                    }

                    ComposeSection(title: "가게", caption: "게시글과 연결할 가게를 선택할 수 있어요") {
                        Button {
                            isStorePickerPresented = true
                        } label: {
                            selectedStoreCard
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }

                if let error = pickerVM.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100)
            .tapToHideKeyboard()
        }
        .background(YP2Color.backgroundPrimary)
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(YP2Color.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomSubmitBar
        }
        .onAppear {
            guard !didConfigure else { return }
            viewModel.configure(for: mode, existing: existingPost)
            if case .edit(let post) = mode {
                pickerVM.configureExistingFiles(post.files)
            }
            didConfigure = true
        }
        .onChange(of: viewModel.didSubmit) { _, submitted in
            if submitted { dismiss() }
        }
        .sheet(isPresented: $isStorePickerPresented) {
            NavigationStack {
                CommunityStorePickerView(
                    viewModel: storePickerVM,
                    selectedStoreId: viewModel.storeId,
                    onSelect: { store in
                        viewModel.selectStore(store)
                        isStorePickerPresented = false
                    },
                    onClear: {
                        viewModel.clearStoreSelection()
                        isStorePickerPresented = false
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var composeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerEyebrow)
                .font(.custom("Pretendard-Bold", size: 12))
                .foregroundStyle(YP2Color.textMuted)

            Text(navigationTitle)
                .font(.custom("Pretendard-Bold", size: 30))
                .foregroundStyle(YP2Color.textPrimary)

            Text("동네 픽업 경험을 담백하게 공유해 주세요.")
                .font(.custom("Pretendard-Medium", size: 14))
                .foregroundStyle(YP2Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedStoreCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(YP2Color.fog)

                if viewModel.hasSelectedStore {
                    CachedImage(path: viewModel.selectedStoreImagePath)
                } else {
                    Image(systemName: "storefront")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(YP2Color.ink)
                }
            }
            .frame(width: 48, height: 48)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedStoreDisplayName)
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(viewModel.hasSelectedStore ? YP2Color.textPrimary : YP2Color.textTertiary)
                    .lineLimit(1)

                Text(viewModel.selectedStoreSubtitle ?? "선택 안 함")
                    .font(.custom("Pretendard-Medium", size: 12))
                    .foregroundStyle(YP2Color.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(YP2Color.textTertiary)
        }
        .padding(14)
        .background(YP2Color.backgroundPrimary)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private var bottomSubmitBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)

            Button {
                Task {
                    await viewModel.submit(
                        existingFileURLs: pickerVM.existingFilePaths,
                        mediaItems: pickerVM.mediaItems
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSubmitting || pickerVM.isProcessing {
                        ProgressView()
                            .tint(YP2Color.ink)
                    }

                    Text(submitTitle)
                        .font(.custom("Pretendard-Bold", size: 16))
                }
                .foregroundStyle(canTapSubmit ? YP2Color.ink : YP2Color.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canTapSubmit ? YP2Color.order : YP2Color.fog)
                .overlay {
                    Rectangle()
                        .stroke(YP2Color.borderDefault, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canTapSubmit)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(YP2Color.backgroundPrimary)
        }
    }

    private var canTapSubmit: Bool {
        viewModel.canSubmit && !viewModel.isSubmitting && !pickerVM.isProcessing
    }

    private var submitTitle: String {
        switch mode {
        case .create: return "게시글 등록"
        case .edit: return "수정 완료"
        }
    }

    private var headerEyebrow: String {
        switch mode {
        case .create: return "WRITE PICK"
        case .edit: return "EDIT PICK"
        }
    }

    private func formTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.custom("Pretendard-Medium", size: 15))
            .foregroundStyle(YP2Color.textPrimary)
            .tint(YP2Color.ink)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(YP2Color.fog)
            .overlay {
                Rectangle()
                    .stroke(YP2Color.borderDefault, lineWidth: 1)
            }
    }

    private func formEditor(placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if viewModel.content.isEmpty {
                Text(placeholder)
                    .font(.custom("Pretendard-Medium", size: 15))
                    .foregroundStyle(YP2Color.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
            }

            TextEditor(text: $viewModel.content)
                .font(.custom("Pretendard-Medium", size: 15))
                .foregroundStyle(YP2Color.textPrimary)
                .tint(YP2Color.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minHeight: 180)
        }
        .background(YP2Color.fog)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Pretendard-Medium", size: 11))
            .foregroundStyle(YPColor.semanticDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(YPColor.semanticDanger)

            Text(message)
                .font(.custom("Pretendard-Medium", size: 12))
                .foregroundStyle(YP2Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(YP2Color.fog)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private struct ComposeSection<Content: View>: View {
        let title: String
        let required: Bool
        let caption: String?
        let content: Content

        init(
            title: String,
            required: Bool = false,
            caption: String? = nil,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.required = required
            self.caption = caption
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.custom("Pretendard-Bold", size: 14))
                        .foregroundStyle(YP2Color.textPrimary)

                    if required {
                        Text("*")
                            .font(.custom("Pretendard-Bold", size: 14))
                            .foregroundStyle(YP2Color.order)
                    }

                    Spacer()

                    if let caption {
                        Text(caption)
                            .font(.custom("Pretendard-Medium", size: 11))
                            .foregroundStyle(YP2Color.textMuted)
                            .lineLimit(1)
                    }
                }

                content
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "게시글 작성"
        case .edit: return "게시글 수정"
        }
    }

}

private struct CommunityStorePickerView: View {
    @Bindable var viewModel: CommunityStorePickerViewModel
    let selectedStoreId: String
    let onSelect: (StoreSummary) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 14)

            content
        }
        .background(YP2Color.backgroundPrimary)
        .navigationTitle("가게 선택")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(YP2Color.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("닫기") { dismiss() }
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.textSecondary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !selectedStoreId.isEmpty {
                    Button("선택 해제") { onClear() }
                        .font(.custom("Pretendard-Bold", size: 14))
                        .foregroundStyle(YPColor.semanticDanger)
                }
            }
        }
        .task {
            await viewModel.loadStoresIfNeeded()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(YP2Color.textTertiary)

            TextField("가게명, 카테고리 검색", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.custom("Pretendard-Medium", size: 14))
                .foregroundStyle(YP2Color.textPrimary)
                .tint(YP2Color.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(YP2Color.fog)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stores.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.stores.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.custom("Pretendard-Medium", size: 12))
                    .foregroundStyle(YPColor.semanticDanger)
                    .multilineTextAlignment(.center)

                Button("다시 불러오기") {
                    Task { await viewModel.refreshStores() }
                }
                .font(.custom("Pretendard-Bold", size: 14))
                .foregroundStyle(YP2Color.ink)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(YP2Color.order)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredStores.isEmpty {
            Text(viewModel.searchText.isEmpty ? "선택할 수 있는 가게가 없어요." : "검색 결과가 없어요.")
                .font(.custom("Pretendard-Medium", size: 14))
                .foregroundStyle(YP2Color.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.filteredStores) { store in
                    Button {
                        onSelect(store)
                    } label: {
                        StorePickerRow(
                            store: store,
                            isSelected: store.store_id == selectedStoreId
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(YP2Color.backgroundPrimary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(YP2Color.backgroundPrimary)
            .refreshable {
                await viewModel.refreshStores()
            }
        }
    }
}

private struct StorePickerRow: View {
    let store: StoreSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(path: store.store_image_urls?.first)
                .frame(width: 52, height: 52)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(store.name ?? "이름 없는 가게")
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.custom("Pretendard-Medium", size: 12))
                    .foregroundStyle(YP2Color.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(YP2Color.ink)
                    .frame(width: 30, height: 30)
                    .background(YP2Color.order)
            }
        }
        .padding(12)
        .background(isSelected ? YP2Color.fog : YP2Color.backgroundPrimary)
        .overlay {
            Rectangle()
                .stroke(isSelected ? YP2Color.ink : YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private var subtitle: String {
        let parts = [
            store.category,
            formattedDistance(store.distance)
        ].compactMap { value -> String? in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }

        return parts.isEmpty ? "가게 정보 없음" : parts.joined(separator: " · ")
    }

    private func formattedDistance(_ distance: Double?) -> String? {
        guard let distance else { return nil }
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        }
        return String(format: "%.0fm", distance)
    }
}
