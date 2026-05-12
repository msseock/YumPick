import Foundation
import PhotosUI
import SwiftUI

enum ReviewMode {
    case create(storeId: String, orderCode: String)
    case edit(storeId: String, reviewId: String)
}

@Observable
final class WriteReviewViewModel {
    var rating: Int = 5
    var content: String = ""
    var selectedItems: [PhotosPickerItem] = []
    var selectedImages: [UIImage] = []
    var existingImageURLs: [String] = []
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String? = nil
    var isSuccess = false

    let mode: ReviewMode
    private let client: ReviewClientProtocol

    init(mode: ReviewMode, client: ReviewClientProtocol = FixtureClientFactory.reviewClient()) {
        self.mode = mode
        self.client = client
    }

    var storeId: String {
        switch mode {
        case .create(let storeId, _): return storeId
        case .edit(let storeId, _): return storeId
        }
    }

    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    func loadIfEditing() async {
        guard case .edit(let storeId, let reviewId) = mode else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await client.fetchReview(storeId: storeId, reviewId: reviewId)
            rating = detail.rating
            content = detail.content
            existingImageURLs = detail.review_image_urls
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSelectedImages() async {
        var images: [UIImage] = []
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }

    func submit() async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "리뷰 내용을 입력해주세요."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let uploadedURLs = try await uploadImages()
            let allImageURLs = existingImageURLs + uploadedURLs

            switch mode {
            case .create(let storeId, let orderCode):
                let request = CreateReviewRequest(
                    content: content,
                    rating: rating,
                    review_image_urls: allImageURLs,
                    order_code: orderCode
                )
                _ = try await client.createReview(storeId: storeId, request: request)
            case .edit(let storeId, let reviewId):
                let request = UpdateReviewRequest(
                    content: content,
                    rating: rating,
                    review_image_urls: allImageURLs
                )
                _ = try await client.updateReview(storeId: storeId, reviewId: reviewId, request: request)
            }
            isSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeExistingImage(at index: Int) {
        existingImageURLs.remove(at: index)
    }

    private func uploadImages() async throws -> [String] {
        guard !selectedImages.isEmpty else { return [] }
        let parts: [MultipartData] = selectedImages.compactMap { image in
            guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
            return MultipartData(name: "files", fileName: "image.jpg", mimeType: "image/jpeg", data: data)
        }
        return try await client.uploadFiles(storeId: storeId, parts: parts)
    }
}
