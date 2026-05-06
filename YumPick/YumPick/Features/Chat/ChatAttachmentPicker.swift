import PhotosUI
import SwiftUI

struct ChatAttachmentPicker: UIViewControllerRepresentable {
    let maxCount: Int
    let onPick: ([ChatAttachment]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = max(1, maxCount)
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: ([ChatAttachment]) -> Void

        init(onPick: @escaping ([ChatAttachment]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            Task {
                var attachments: [ChatAttachment] = []
                for result in results {
                    guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                    if let image = try? await result.itemProvider.loadImage(),
                       let compressed = compress(image) {
                        attachments.append(compressed)
                    }
                }
                await MainActor.run { self.onPick(attachments) }
            }
        }

        private func compress(_ image: UIImage) -> ChatAttachment? {
            let maxDimension: CGFloat = 1080
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

            var quality: CGFloat = 0.7
            var data = resized.jpegData(compressionQuality: quality)

            // 5MB 초과 시 추가 다운스케일
            let maxBytes = 5 * 1024 * 1024
            while let d = data, d.count > maxBytes, quality > 0.1 {
                quality -= 0.1
                data = resized.jpegData(compressionQuality: quality)
            }

            guard let finalData = data else { return nil }
            let fileName = "\(UUID().uuidString).jpg"
            return ChatAttachment(
                kind: .image,
                data: finalData,
                fileName: fileName,
                mimeType: "image/jpeg",
                thumbnail: resized
            )
        }
    }
}

private extension NSItemProvider {
    func loadImage() async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}
