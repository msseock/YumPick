import SwiftUI

struct CommunityComposeView: View {
    let mode: ComposeMode
    var existingPost: PostDetail? = nil

    @State private var viewModel = CommunityComposeViewModel()
    @State private var storePickerVM = CommunityStorePickerViewModel()
    @StateObject private var pickerVM = CommunityMediaPickerViewModel()
    @State private var isStorePickerPresented = false
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
                            .foregroundStyle(YPColor.semanticDanger)
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

                // 가게 선택
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("가게 (선택)", required: false)
                    Button {
                        isStorePickerPresented = true
                    } label: {
                        selectedStoreCard
                    }
                    .buttonStyle(.plain)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.semanticDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = pickerVM.errorMessage {
                    Text(error)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.semanticDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .tapToHideKeyboard()
        }
        .scrollDismissesKeyboard(.immediately)
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

    private var selectedStoreCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(YPColor.backgroundBrandSubtle)

                if viewModel.hasSelectedStore {
                    CachedImage(path: viewModel.selectedStoreImagePath)
                } else {
                    Image(systemName: "storefront")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(YPColor.actionPrimary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedStoreDisplayName)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(viewModel.hasSelectedStore ? YPColor.textPrimary : YPColor.textTertiary)
                    .lineLimit(1)

                Text(viewModel.selectedStoreSubtitle ?? "게시글과 연결할 가게를 선택할 수 있어요")
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(YPColor.textTertiary)
        }
        .padding(12)
        .background(YPColor.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(YPColor.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

private struct CommunityStorePickerView: View {
    @Bindable var viewModel: CommunityStorePickerViewModel
    let selectedStoreId: String
    let onSelect: (StoreSummary) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            content
        }
        .background(YPColor.backgroundPrimary)
        .navigationTitle("가게 선택")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("닫기") { dismiss() }
                    .foregroundStyle(YPColor.textSecondary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !selectedStoreId.isEmpty {
                    Button("선택 해제") { onClear() }
                        .font(YPFont.body3Bold)
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
                .foregroundStyle(YPColor.textTertiary)

            TextField("가게명, 카테고리 검색", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textPrimary)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stores.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.stores.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.semanticDanger)
                    .multilineTextAlignment(.center)

                Button("다시 불러오기") {
                    Task { await viewModel.refreshStores() }
                }
                .font(YPFont.body3Bold)
                .foregroundStyle(YPColor.actionPrimary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredStores.isEmpty {
            Text(viewModel.searchText.isEmpty ? "선택할 수 있는 가게가 없어요." : "검색 결과가 없어요.")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(YPColor.backgroundPrimary)
                }
            }
            .listStyle(.plain)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(store.name ?? "이름 없는 가게")
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(YPColor.actionPrimary)
            }
        }
        .padding(12)
        .background(isSelected ? YPColor.backgroundBrandSubtle : YPColor.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? YPColor.actionPrimary : YPColor.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
