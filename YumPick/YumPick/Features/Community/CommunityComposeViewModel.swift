import Foundation
import CoreLocation

// 카테고리에 사용 금지된 특수문자
private let forbiddenCategoryChars = CharacterSet(charactersIn: ".,?*-@+^${}()|[]\\")

@Observable
final class CommunityComposeViewModel {
    var category: String = ""
    var title: String = ""
    var content: String = ""
    var storeId: String = ""
    var selectedStoreName: String? = nil
    var selectedStoreCategory: String? = nil
    var selectedStoreImagePath: String? = nil
    var isSubmitting = false
    var errorMessage: String? = nil
    var didSubmit = false
    var submittedPostId: String? = nil

    private var editingPostId: String? = nil

    private let client: CommunityClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: CommunityClientProtocol = FixtureClientFactory.communityClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared
    ) {
        self.client = client
        self.locationManager = locationManager
    }

    func configure(for mode: ComposeMode, existing post: PostDetail? = nil) {
        switch mode {
        case .create:
            break
        case .edit(let post):
            editingPostId = post.post_id
            category = post.category
            title = post.title
            content = post.content
            applySelectedStore(post.store)
        }
    }

    var hasSelectedStore: Bool {
        !storeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedStoreDisplayName: String {
        selectedStoreName?.nilIfBlank ?? (hasSelectedStore ? "선택된 가게" : "가게를 선택해 주세요")
    }

    var selectedStoreSubtitle: String? {
        selectedStoreCategory?.nilIfBlank
    }

    func selectStore(_ store: StoreSummary) {
        storeId = store.store_id
        selectedStoreName = store.name
        selectedStoreCategory = store.category
        selectedStoreImagePath = store.store_image_urls?.first
    }

    func clearStoreSelection() {
        storeId = ""
        selectedStoreName = nil
        selectedStoreCategory = nil
        selectedStoreImagePath = nil
    }

    var canSubmit: Bool {
        !category.trimmingCharacters(in: .whitespaces).isEmpty &&
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty &&
        !hasForbiddenCategoryChars
    }

    var hasForbiddenCategoryChars: Bool {
        category.unicodeScalars.contains { forbiddenCategoryChars.contains($0) }
    }

    func submit(existingFileURLs: [String], mediaItems: [PostMedia]) async {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        let geo = await locationManager.currentLocation()
            ?? Geolocation(longitude: 126.9780, latitude: 37.5665)

        do {
            // 1단계: 미디어 업로드
            let uploadedFileURLs: [String]
            if mediaItems.isEmpty {
                uploadedFileURLs = []
            } else {
                let parts = mediaItems.compactMap { media -> MultipartData? in
                    guard let data = media.data else { return nil }
                    return MultipartData(
                        name: "files",
                        fileName: media.fileName,
                        mimeType: media.mimeType,
                        data: data
                    )
                }
                uploadedFileURLs = try await client.uploadFiles(parts: parts)
            }
            let fileURLs = existingFileURLs + uploadedFileURLs

            // 2단계: 게시글 생성 or 수정
            if let postId = editingPostId {
                let request = UpdatePostRequest(
                    category: category,
                    title: title,
                    content: content,
                    store_id: storeId.isEmpty ? nil : storeId,
                    latitude: geo.latitude,
                    longitude: geo.longitude,
                    files: fileURLs
                )
                let updated = try await client.updatePost(postId: postId, request)
                submittedPostId = updated.post_id
            } else {
                let request = CreatePostRequest(
                    category: category,
                    title: title,
                    content: content,
                    store_id: storeId.isEmpty ? nil : storeId,
                    latitude: geo.latitude,
                    longitude: geo.longitude,
                    files: fileURLs.isEmpty ? nil : fileURLs
                )
                let created = try await client.createPost(request)
                submittedPostId = created.post_id
            }

            didSubmit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applySelectedStore(_ store: PostStore?) {
        storeId = store?.id ?? ""
        selectedStoreName = store?.name
        selectedStoreCategory = store?.category
        selectedStoreImagePath = store?.store_image_urls?.first
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
