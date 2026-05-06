import Foundation
import Network

@MainActor
@Observable
final class VideoDetailViewModel {
    enum LoadState {
        case idle
        case loading
        case ready
        case failed(String)
    }

    let video: Video
    let player: VideoPlayerViewModel

    var loadState: LoadState = .idle
    var streamInfo: StreamInfo? = nil
    var selectedQuality: String? = nil

    private let client: VideoClientProtocol
    private var hasInitiallyLoaded = false
    private var pathMonitor: NWPathMonitor?
    private var lastKnownPath: NWPath.Status = .satisfied
    private var hasRecoveredFromExpiry = false

    init(
        video: Video,
        client: VideoClientProtocol = VideoClient(),
        player: VideoPlayerViewModel? = nil
    ) {
        self.video = video
        self.client = client
        self.player = player ?? VideoPlayerViewModel()
    }

    var availableQualities: [String] {
        streamInfo?.qualities.map { $0.quality } ?? []
    }

    // MARK: - Lifecycle

    func onAppear() async {
        startNetworkMonitor()
        guard !hasInitiallyLoaded else { return }
        await loadStream()
    }

    func onDisappear() {
        stopNetworkMonitor()
        player.unload()
    }

    // MARK: - Stream

    func loadStream() async {
        loadState = .loading
        do {
            let info = try await client.fetchStream(videoId: video.video_id)
            streamInfo = info
            selectedQuality = nil // auto by default (master playlist)
            hasInitiallyLoaded = true
            hasRecoveredFromExpiry = false
            guard let url = URL(string: info.stream_url) else {
                loadState = .failed("스트리밍 URL이 올바르지 않습니다")
                return
            }
            player.load(url: url, autoPlay: true)
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 토큰 만료 등으로 실패한 경우 URL을 재발급하고 현재 위치에서 재개.
    func recoverFromPlaybackFailure() async {
        guard !hasRecoveredFromExpiry else { return }
        hasRecoveredFromExpiry = true

        let resumeAt = player.currentTime
        do {
            let info = try await client.fetchStream(videoId: video.video_id)
            streamInfo = info
            let urlString: String
            if let q = selectedQuality, let match = info.qualities.first(where: { $0.quality == q }) {
                urlString = match.url
            } else {
                urlString = info.stream_url
            }
            guard let url = URL(string: urlString) else {
                loadState = .failed("스트리밍 URL이 올바르지 않습니다")
                return
            }
            player.load(url: url, autoPlay: false)
            await player.seek(to: resumeAt)
            player.play()
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Quality

    func selectQuality(_ quality: String?) async {
        guard let info = streamInfo else { return }
        selectedQuality = quality
        let urlString: String
        if let quality, let match = info.qualities.first(where: { $0.quality == quality }) {
            urlString = match.url
        } else {
            urlString = info.stream_url
        }
        guard let url = URL(string: urlString) else { return }
        await player.switchSource(url: url)
    }

    // MARK: - Network

    private func startNetworkMonitor() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let previous = self.lastKnownPath
                self.lastKnownPath = path.status
                if previous != .satisfied && path.status == .satisfied {
                    // 네트워크 재연결 → 재생 실패 상태였으면 자동 복구
                    if case .failed = self.player.state {
                        self.hasRecoveredFromExpiry = false
                        await self.recoverFromPlaybackFailure()
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        pathMonitor = monitor
    }

    private func stopNetworkMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
}
