import SwiftUI
import AVKit

private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "wmv"]

func isVideoPath(_ path: String) -> Bool {
    let ext = (path as NSString).pathExtension.lowercased()
    return videoExtensions.contains(ext)
}

// MARK: - VideoPlayerView

struct VideoPlayerView: View {
    let path: String
    var autoPlay: Bool = false

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                Color.black
                    .overlay {
                        Button {
                            setupAndPlay()
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
            }
        }
        .onAppear {
            if autoPlay && player == nil {
                setupAndPlay()
            }
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
            isPlaying = false
        }
    }

    private func setupAndPlay() {
        guard let url = FixtureFileResolver.remoteURL(from: path) else { return }

        let headers: [String: String] = {
            var h = ["SeSACKey": SecretConstants.sesacKey]
            if let token = KeychainManager.shared.read(key: .accessToken) {
                h["Authorization"] = token
            }
            return h
        }()

        let options = url.isFileURL ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        newPlayer.play()
        isPlaying = true
    }

}

// MARK: - Video Thumbnail Overlay

struct VideoThumbnailOverlay: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.25)
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .padding(6)
        }
    }
}
