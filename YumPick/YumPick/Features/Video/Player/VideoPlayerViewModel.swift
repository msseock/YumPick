import AVFoundation
import Combine
import Foundation

@MainActor
@Observable
final class VideoPlayerViewModel {
    enum PlaybackState {
        case idle
        case loading
        case ready
        case playing
        case paused
        case buffering
        case ended
        case failed(String)
    }

    let player: AVPlayer = AVPlayer()

    var state: PlaybackState = .idle
    var currentTime: Double = 0
    var duration: Double = 0
    var bufferedTime: Double = 0
    var isMuted: Bool = false
    var isPlaying: Bool = false
    var isSeeking: Bool = false

    private var statusObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var loadedRangesObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var errorLogObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var wantsPlayback = false

    // 정리는 명시적으로 `unload()` 호출로 수행. 화면 dismiss 시 View에서 호출.

    /// PiP/백그라운드 재생을 위해 AVAudioSession을 `.playback` 카테고리로 활성화.
    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        if session.category == .playback { return }
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true, options: [])
        } catch {
            // 오디오 세션 설정 실패는 치명적이지 않음. 재생은 시도.
        }
    }

    // MARK: - Loading

    func load(url: URL, autoPlay: Bool = true) {
        #if DEBUG
        print("▶️ [Player] load url=\(url.absoluteString) autoPlay=\(autoPlay)")
        #endif
        configureAudioSessionForPlayback()
        teardownItem()
        state = .loading
        currentTime = 0
        duration = 0
        bufferedTime = 0
        wantsPlayback = autoPlay
        isPlaying = autoPlay

        let item = AVPlayerItem(asset: makeAsset(url: url))
        observeItem(item)
        player.replaceCurrentItem(with: item)
        addPeriodicTimeObserver()
        addEndObserver(for: item)
        addErrorLogObserver(for: item)
        observeTimeControlStatus()

        if autoPlay {
            player.play()
        }
        #if DEBUG
        print("▶️ [Player] replaceCurrentItem 완료, autoPlay 호출=\(autoPlay)")
        #endif
    }

    func unload() {
        player.pause()
        teardownItem()
        state = .idle
        currentTime = 0
        duration = 0
        bufferedTime = 0
        wantsPlayback = false
        isPlaying = false
    }

    // MARK: - Playback control

    func play() {
        wantsPlayback = true
        isPlaying = true
        player.play()
    }

    func pause() {
        wantsPlayback = false
        isPlaying = false
        player.pause()
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) async {
        await seek(to: seconds, constrainedToKnownDuration: true)
    }

    private func seek(to seconds: Double, constrainedToKnownDuration: Bool) async {
        if constrainedToKnownDuration, duration <= 0 { return }
        isSeeking = true
        let target: Double
        if constrainedToKnownDuration, duration > 0 {
            target = max(0, min(seconds, duration))
        } else {
            target = max(0, seconds)
        }
        let time = CMTime(seconds: target, preferredTimescale: 600)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
        isSeeking = false
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    /// 네트워크 환경에 따라 선읽기 버퍼 크기를 조정한다.
    /// WiFi(isExpensive=false)일 때는 0으로 두어 AVFoundation의 적응형 알고리즘에 맡기고,
    /// 셀룰러(isExpensive=true)일 때는 5초로 고정해 데이터를 아낀다.
    func applyBufferStrategy(isExpensive: Bool) {
        guard let item = player.currentItem else { return }
        item.preferredForwardBufferDuration = isExpensive ? 5 : 0
        #if DEBUG
        print("📶 [Player] bufferDuration=\(isExpensive ? "5s" : "0 (system)") (isExpensive=\(isExpensive))")
        #endif
    }

    /// 동일 비디오의 다른 화질 URL로 교체. 현재 위치를 유지한다.
    func switchSource(url: URL) async {
        let resumeAt = currentTime
        let shouldResumePlayback = wantsPlayback || player.rate > 0
        load(url: url, autoPlay: false)
        await seek(to: resumeAt, constrainedToKnownDuration: false)
        if shouldResumePlayback { play() }
    }

    // MARK: - Observation setup

    private func observeItem(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    #if DEBUG
                    print("✅ [Player] status=readyToPlay duration=\(self.duration)")
                    #endif
                    if case .loading = self.state { self.state = .ready }
                case .failed:
                    let message = self.playbackErrorMessage(for: item)
                    #if DEBUG
                    print("❌ [Player] status=failed message=\(message)")
                    if let err = item.error as NSError? {
                        print("   • domain=\(err.domain) code=\(err.code) userInfo=\(err.userInfo)")
                    }
                    #endif
                    self.state = .failed(message)
                case .unknown:
                    #if DEBUG
                    print("⏳ [Player] status=unknown")
                    #endif
                    break
                @unknown default:
                    break
                }
            }
        }

        bufferEmptyObservation = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.isPlaybackBufferEmpty {
                    #if DEBUG
                    print("🌀 [Player] playbackBufferEmpty=true → buffering")
                    #endif
                    self.state = .buffering
                }
            }
        }

        likelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.isPlaybackLikelyToKeepUp, case .buffering = self.state {
                    #if DEBUG
                    print("🌀 [Player] likelyToKeepUp=true → buffering 해제")
                    #endif
                    self.state = self.player.timeControlStatus == .playing ? .playing : .paused
                }
            }
        }

        loadedRangesObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let range = item.loadedTimeRanges.first?.timeRangeValue else { return }
                let buffered = range.start.seconds + range.duration.seconds
                if buffered.isFinite {
                    self.bufferedTime = buffered
                }
            }
        }
    }

    private func makeAsset(url: URL) -> AVURLAsset {
        // 스트리밍 .m3u8 / .m4s 요청에는 Authorization은 불필요하지만 서버 공통 SeSACKey 헤더는 필요.
        let headers: [String: String] = ["SeSACKey": SecretConstants.sesacKey]
        return AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    }

    private func observeTimeControlStatus() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.state = .playing
                case .paused:
                    if case .ended = self.state { return }
                    if case .failed = self.state { return }
                    if case .buffering = self.state { return }
                    self.isPlaying = self.wantsPlayback
                    self.state = .paused
                case .waitingToPlayAtSpecifiedRate:
                    self.state = .buffering
                @unknown default:
                    break
                }
            }
        }
    }

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isSeeking else { return }
                self.currentTime = seconds
                if self.wantsPlayback, self.player.rate > 0 {
                    self.isPlaying = true
                    if case .ended = self.state { return }
                    if case .failed = self.state { return }
                    self.state = .playing
                }
            }
        }
    }

    private func addEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.wantsPlayback = false
                self?.isPlaying = false
                self?.state = .ended
            }
        }
    }

    private func addErrorLogObserver(for item: AVPlayerItem) {
        errorLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            guard let self, let item else { return }
            let message = self.playbackErrorMessage(for: item)
            #if DEBUG
            print("⚠️ AVPlayer Error Log: \(message)")
            #endif
            Task { @MainActor in
                self.wantsPlayback = false
                self.isPlaying = false
                self.state = .failed(message)
            }
        }
    }

    private func playbackErrorMessage(for item: AVPlayerItem) -> String {
        let itemMessage = item.error?.localizedDescription
        let eventMessage = item.errorLog()?.events.last.flatMap { event -> String? in
            let status = event.errorStatusCode
            let comment = event.errorComment ?? event.errorDomain
            guard status != 0 || comment != nil else { return nil }
            return [comment, status == 0 ? nil : "status \(status)"]
                .compactMap { $0 }
                .joined(separator: " / ")
        }

        return eventMessage ?? itemMessage ?? "재생 실패"
    }

    private func teardownItem() {
        statusObservation?.invalidate()
        statusObservation = nil
        bufferEmptyObservation?.invalidate()
        bufferEmptyObservation = nil
        likelyToKeepUpObservation?.invalidate()
        likelyToKeepUpObservation = nil
        loadedRangesObservation?.invalidate()
        loadedRangesObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let errorLogObserver {
            NotificationCenter.default.removeObserver(errorLogObserver)
            self.errorLogObserver = nil
        }
    }
}
