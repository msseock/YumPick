import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatAttachmentPicker: UIViewControllerRepresentable {
    let maxCount: Int
    let onPick: ([ChatAttachment]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos])
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
                    if let attachment = await load(from: result.itemProvider) {
                        attachments.append(attachment)
                    }
                }
                await MainActor.run { self.onPick(attachments) }
            }
        }

        private func load(from provider: NSItemProvider) async -> ChatAttachment? {
            if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
                return await loadGIF(from: provider)
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                return await loadVideo(from: provider)
            }
            if provider.canLoadObject(ofClass: UIImage.self),
               let image = try? await provider.loadUIImage() {
                return compress(image)
            }
            return nil
        }

        private func loadGIF(from provider: NSItemProvider) async -> ChatAttachment? {
            await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { data, _ in
                    guard let data else { return continuation.resume(returning: nil) }
                    let thumbnail = UIImage(data: data)
                    continuation.resume(returning: ChatAttachment(
                        kind: .gif,
                        data: data,
                        fileName: "\(UUID().uuidString).gif",
                        mimeType: "image/gif",
                        thumbnail: thumbnail
                    ))
                }
            }
        }

        private func loadVideo(from provider: NSItemProvider) async -> ChatAttachment? {
            await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else { return continuation.resume(returning: nil) }
                    let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(ext)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    guard let data = try? Data(contentsOf: tempURL) else {
                        try? FileManager.default.removeItem(at: tempURL)
                        return continuation.resume(returning: nil)
                    }
                    let thumbnail = Self.videoThumbnail(from: tempURL)
                    let mimeType = ext.lowercased() == "mov" ? "video/quicktime" : "video/mp4"
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: ChatAttachment(
                        kind: .video,
                        data: data,
                        fileName: "\(UUID().uuidString).\(ext)",
                        mimeType: mimeType,
                        thumbnail: thumbnail
                    ))
                }
            }
        }

        private static func videoThumbnail(from url: URL) -> UIImage? {
            let generator = AVAssetImageGenerator(asset: AVAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }

        private func compress(_ image: UIImage) -> ChatAttachment? {
            let maxDimension: CGFloat = 1080
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = UIGraphicsImageRenderer(size: newSize)
                .image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

            var quality: CGFloat = 0.7
            var data = resized.jpegData(compressionQuality: quality)
            let maxBytes = 5 * 1024 * 1024
            while let d = data, d.count > maxBytes, quality > 0.1 {
                quality -= 0.1
                data = resized.jpegData(compressionQuality: quality)
            }
            guard let finalData = data else { return nil }
            return ChatAttachment(
                kind: .image,
                data: finalData,
                fileName: "\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                thumbnail: resized
            )
        }
    }
}

private extension NSItemProvider {
    func loadUIImage() async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: UIImage.self) { object, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: object as? UIImage) }
            }
        }
    }
}
