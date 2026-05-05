import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let path: String
    var showsPlayIcon: Bool = true

    @State private var thumbnail: UIImage? = nil

    var body: some View {
        ZStack {
            Color.black

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            }

            if showsPlayIcon {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
        }
        .clipped()
        .task(id: path) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if let cached = VideoThumbnailCache.shared.image(for: path) {
            thumbnail = cached
            return
        }

        guard let url = resolveURL(from: path) else { return }

        let headers: [String: String] = {
            var h = ["SeSACKey": SecretConstants.sesacKey]
            if let token = KeychainManager.shared.read(key: .accessToken) {
                h["Authorization"] = token
            }
            return h
        }()

        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)

        let time = CMTime(seconds: 0.0, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            let uiImage = UIImage(cgImage: cgImage)
            VideoThumbnailCache.shared.set(uiImage, for: path)
            await MainActor.run { thumbnail = uiImage }
        } catch {
            // 실패 시 placeholder 유지
        }
    }

    private func resolveURL(from path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        let base = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let apiPath: String = {
            let p = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
            return p.hasPrefix("/data/") ? "/v1\(p)" : p
        }()

        return URL(string: base + apiPath)
    }
}

// MARK: - Cache

final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
    }

    func image(for path: String) -> UIImage? {
        cache.object(forKey: path as NSString)
    }

    func set(_ image: UIImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}
