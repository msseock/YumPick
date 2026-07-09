import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// 5MB limit per file
private let maxFileSizeBytes = 5 * 1024 * 1024

enum MediaPickerError: LocalizedError {
    case oversized(fileName: String)
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .oversized(let name): return "\(name) 파일이 5MB를 초과합니다."
        case .loadFailed:          return "미디어를 불러오는 데 실패했습니다."
        }
    }
}

@MainActor
final class CommunityMediaPickerViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var existingFilePaths: [String] = []
    @Published var mediaItems: [PostMedia] = []
    @Published var errorMessage: String? = nil
    @Published var isProcessing = false

    var totalMediaCount: Int {
        existingFilePaths.count + mediaItems.count
    }

    func configureExistingFiles(_ paths: [String]) {
        existingFilePaths = paths
    }

    func processSelectedItems(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil

        var result: [PostMedia] = []
        for item in items {
            do {
                let media = try await loadMedia(from: item)
                result.append(media)
            } catch let error as MediaPickerError {
                errorMessage = error.localizedDescription
                break
            } catch {
                errorMessage = MediaPickerError.loadFailed.localizedDescription
                break
            }
        }
        mediaItems = result
    }

    func remove(at index: Int) {
        guard mediaItems.indices.contains(index) else { return }
        mediaItems.remove(at: index)
        if selectedItems.indices.contains(index) {
            selectedItems.remove(at: index)
        }
    }

    func removeExistingFile(at index: Int) {
        guard existingFilePaths.indices.contains(index) else { return }
        existingFilePaths.remove(at: index)
    }

    private func loadMedia(from item: PhotosPickerItem) async throws -> PostMedia {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            return try await loadVideo(from: item)
        } else {
            return try await loadImage(from: item)
        }
    }

    private func loadImage(from item: PhotosPickerItem) async throws -> PostMedia {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            throw MediaPickerError.loadFailed
        }

        let fileName = "\(UUID().uuidString).jpg"

        if data.count <= maxFileSizeBytes {
            return .image(data, fileName: fileName)
        }

        // 압축 시도
        guard let image = UIImage(data: data),
              let compressed = compressImage(image, targetBytes: maxFileSizeBytes) else {
            throw MediaPickerError.oversized(fileName: fileName)
        }
        return .image(compressed, fileName: fileName)
    }

    private func loadVideo(from item: PhotosPickerItem) async throws -> PostMedia {
        guard let movie = try? await item.loadTransferable(type: VideoTransferable.self) else {
            throw MediaPickerError.loadFailed
        }

        let fileName = "\(UUID().uuidString).mp4"
        let fileSize = (try? movie.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if fileSize > maxFileSizeBytes {
            throw MediaPickerError.oversized(fileName: fileName)
        }

        let thumbnail = await extractThumbnail(from: movie.url)
        return .video(movie.url, thumbnail: thumbnail, fileName: fileName)
    }

    private func compressImage(_ image: UIImage, targetBytes: Int) -> Data? {
        var quality: CGFloat = 0.8
        while quality > 0.1 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= targetBytes {
                return data
            }
            quality -= 0.2
        }
        return nil
    }

    private func extractThumbnail(from url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoTransferable(url: dest)
        }
    }
}

// MARK: - Media Grid View

struct MediaGridView: View {
    @ObservedObject var pickerVM: CommunityMediaPickerViewModel
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 추가 버튼
                    if pickerVM.totalMediaCount < maxCount {
                        PhotosPicker(
                            selection: $pickerVM.selectedItems,
                            maxSelectionCount: max(0, maxCount - pickerVM.existingFilePaths.count),
                            matching: .any(of: [.images, .videos])
                        ) {
                            addButton
                        }
                        .onChange(of: pickerVM.selectedItems) { _, newItems in
                            Task { await pickerVM.processSelectedItems(newItems) }
                        }
                    }

                    // 기존 미디어 썸네일
                    ForEach(Array(pickerVM.existingFilePaths.enumerated()), id: \.offset) { idx, path in
                        existingMediaThumbnail(path: path, index: idx)
                    }

                    // 선택된 미디어 썸네일
                    ForEach(Array(pickerVM.mediaItems.enumerated()), id: \.offset) { idx, media in
                        mediaThumbnail(media: media, index: idx)
                    }
                }
                .padding(.vertical, 2)
            }

            if pickerVM.isProcessing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("미디어 처리 중...")
                        .font(.custom("Pretendard-Medium", size: 12))
                        .foregroundStyle(YP2Color.textMuted)
                }
            }
        }
    }

    private var addButton: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(YP2Color.ink)
            Text("\(pickerVM.totalMediaCount)/\(maxCount)")
                .font(.custom("Pretendard-Bold", size: 11))
                .foregroundStyle(YP2Color.textMuted)
        }
        .frame(width: 84, height: 84)
        .background(YP2Color.fog)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private func existingMediaThumbnail(path: String, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if isVideoPath(path) {
                    VideoThumbnailView(path: path, showsPlayIcon: false)
                } else {
                    CachedImage(path: path)
                }
            }
            .frame(width: 84, height: 84)
            .clipped()

            if isVideoPath(path) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(YP2Color.paper)
                    .padding(4)
                    .background(YP2Color.overlay)
                    .clipShape(Circle())
                    .padding(4)
            }

            Button {
                pickerVM.removeExistingFile(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(YP2Color.paper)
                    .background(YP2Color.overlay, in: Circle())
            }
            .offset(x: 4, y: -4)
        }
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    private func mediaThumbnail(media: PostMedia, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            thumbnailImage(for: media)
                .frame(width: 84, height: 84)
                .clipped()

            if case .video = media {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(YP2Color.paper)
                    .padding(4)
                    .background(YP2Color.overlay)
                    .clipShape(Circle())
                    .padding(4)
            }

            Button {
                pickerVM.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(YP2Color.paper)
                    .background(YP2Color.overlay, in: Circle())
            }
            .offset(x: 4, y: -4)
        }
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func thumbnailImage(for media: PostMedia) -> some View {
        switch media {
        case .image(let data, _):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderRect
            }
        case .video(_, let thumbnail, _):
            if let thumb = thumbnail, let uiImage = UIImage(data: thumb) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderRect
            }
        }
    }

    private var placeholderRect: some View {
        Rectangle()
            .fill(YP2Color.fog)
    }
}
