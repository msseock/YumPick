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
    var subtitleCues: [SubtitleCue] = []
    var selectedSubtitleLanguage: String? = nil
    var isSubtitleEnabled: Bool = true
    var isLiked: Bool
    var likeCount: Int
    private var isLikeRequestInFlight = false

    private let client: VideoClientProtocol
    private var hasInitiallyLoaded = false
    private var pathMonitor: NWPathMonitor?
    private var lastKnownPath: NWPath.Status = .satisfied
    private var hasRecoveredFromExpiry = false
    private var subtitleLoadTask: Task<Void, Never>? = nil

    init(
        video: Video,
        client: VideoClientProtocol = VideoClient(),
        player: VideoPlayerViewModel? = nil
    ) {
        self.video = video
        self.client = client
        self.player = player ?? VideoPlayerViewModel()
        let cached = VideoLikeStateStore.shared.state(
            for: video.video_id,
            fallback: .init(isLiked: video.is_liked, likeCount: video.like_count)
        )
        self.isLiked = cached.isLiked
        self.likeCount = cached.likeCount
    }

    var availableQualities: [String] {
        streamInfo?.qualities.map { $0.quality } ?? []
    }

    var availableSubtitles: [StreamInfo.Subtitle] {
        streamInfo?.subtitles ?? []
    }

    var currentSubtitleText: String? {
        guard isSubtitleEnabled, !subtitleCues.isEmpty else { return nil }
        let t = player.currentTime
        return subtitleCues.first(where: { $0.start <= t && t <= $0.end })?.text
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
            selectedQuality = nil
            hasInitiallyLoaded = true
            hasRecoveredFromExpiry = false
            guard let url = resolveMediaURL(from: info.stream_url) else {
                loadState = .failed("스트리밍 URL이 올바르지 않습니다")
                return
            }
            player.load(url: url, autoPlay: true)
            loadState = .ready
            loadDefaultSubtitleIfNeeded(from: info)
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
            guard let url = resolveMediaURL(from: urlString) else {
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
        guard let url = resolveMediaURL(from: urlString) else { return }
        await player.switchSource(url: url)
    }

    // MARK: - Subtitles

    private func loadDefaultSubtitleIfNeeded(from info: StreamInfo) {
        guard !info.subtitles.isEmpty else {
            subtitleCues = []
            selectedSubtitleLanguage = nil
            return
        }
        let preferred = info.subtitles.first(where: { $0.is_default }) ?? info.subtitles.first
        guard let preferred else { return }
        Task { await selectSubtitle(language: preferred.language) }
    }

    func selectSubtitle(language: String?) async {
        selectedSubtitleLanguage = language
        subtitleLoadTask?.cancel()
        guard let language, let subtitle = streamInfo?.subtitles.first(where: { $0.language == language }) else {
            subtitleCues = []
            return
        }
        guard let url = resolveMediaURL(from: subtitle.url) else {
            subtitleCues = []
            return
        }
        let task = Task<Void, Never> { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(for: Self.makeAuthenticatedRequest(url: url))
                guard !Task.isCancelled else { return }
                let text = String(data: data, encoding: .utf8) ?? ""
                let cues = WebVTTParser.parse(text)
                await MainActor.run {
                    guard let self else { return }
                    self.subtitleCues = cues
                }
            } catch {
                // 자막 다운로드 실패는 무시 (재생은 계속)
                await MainActor.run {
                    guard let self else { return }
                    self.subtitleCues = []
                }
            }
        }
        subtitleLoadTask = task
    }

    func toggleSubtitle() {
        isSubtitleEnabled.toggle()
    }

    // MARK: - Like

    func toggleLike() async {
        guard !isLikeRequestInFlight else { return }
        let previousLiked = isLiked
        let previousCount = likeCount
        let nextLiked = !previousLiked
        let nextCount = max(0, previousCount + (nextLiked ? 1 : -1))

        isLiked = nextLiked
        likeCount = nextCount
        VideoLikeStateStore.shared.update(videoId: video.video_id, isLiked: nextLiked, likeCount: nextCount)

        isLikeRequestInFlight = true
        defer { isLikeRequestInFlight = false }
        do {
            let serverStatus = try await client.toggleLike(videoId: video.video_id, likeStatus: nextLiked)
            if serverStatus != nextLiked {
                isLiked = serverStatus
                likeCount = max(0, previousCount + (serverStatus ? 1 : -1))
                VideoLikeStateStore.shared.update(videoId: video.video_id, isLiked: isLiked, likeCount: likeCount)
            }
        } catch {
            isLiked = previousLiked
            likeCount = previousCount
            VideoLikeStateStore.shared.update(videoId: video.video_id, isLiked: previousLiked, likeCount: previousCount)
        }
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

    private func resolveMediaURL(from path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        let base = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        // 서버는 응답에 `/v1` prefix를 빼고 보내므로 클라이언트가 붙여준다.
        let apiPath = normalized.hasPrefix("/v1/") ? normalized : "/v1\(normalized)"

        return URL(string: base + apiPath)
    }

    private static func makeAuthenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")
        if let accessToken = KeychainManager.shared.read(key: .accessToken) {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
