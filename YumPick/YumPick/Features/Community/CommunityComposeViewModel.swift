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
    var isSubmitting = false
    var errorMessage: String? = nil
    var didSubmit = false
    var submittedPostId: String? = nil

    // create 모드일 때 원본 post_id (edit 모드에서 기존 파일 URL 추적용)
    private var editingPostId: String? = nil
    private var existingFileURLs: [String] = []

    private let client: CommunityClientProtocol
    private let locationManager: any LocationManagerProtocol

    init(
        client: CommunityClientProtocol = CommunityClient(),
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
            storeId = post.store?.id ?? ""
            existingFileURLs = post.files
        }
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

    func submit(mediaItems: [PostMedia]) async {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        let geo = await locationManager.currentLocation()
            ?? Geolocation(longitude: 126.9780, latitude: 37.5665)

        do {
            // 1단계: 미디어 업로드
            let fileURLs: [String]
            if mediaItems.isEmpty {
                fileURLs = editingPostId != nil ? existingFileURLs : []
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
                fileURLs = try await client.uploadFiles(parts: parts)
            }

            // 2단계: 게시글 생성 or 수정
            if let postId = editingPostId {
                let request = UpdatePostRequest(
                    category: category,
                    title: title,
                    content: content,
                    store_id: storeId.isEmpty ? nil : storeId,
                    latitude: geo.latitude,
                    longitude: geo.longitude,
                    files: fileURLs.isEmpty ? nil : fileURLs
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
}
