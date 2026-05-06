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
    var isSeeking: Bool = false

    private var statusObservation: NSKeyValueObservation?
    private var bufferEmptyObservation: NSKeyValueObservation?
    private var likelyToKeepUpObservation: NSKeyValueObservation?
    private var loadedRangesObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var errorLogObserver: NSObjectProtocol?
    private var timeObserverToken: Any?

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
        configureAudioSessionForPlayback()
        teardownItem()
        state = .loading
        currentTime = 0
        duration = 0
        bufferedTime = 0

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
    }

    func unload() {
        player.pause()
        teardownItem()
        state = .idle
        currentTime = 0
        duration = 0
        bufferedTime = 0
    }

    // MARK: - Playback control

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlay() {
        if case .playing = state {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) async {
        guard duration > 0 else { return }
        isSeeking = true
        let target = max(0, min(seconds, duration))
        let time = CMTime(seconds: target, preferredTimescale: 600)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
        isSeeking = false
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    /// 동일 비디오의 다른 화질 URL로 교체. 현재 위치를 유지한다.
    func switchSource(url: URL) async {
        let resumeAt = currentTime
        let wasPlaying: Bool
        if case .playing = state { wasPlaying = true } else { wasPlaying = false }
        load(url: url, autoPlay: false)
        await seek(to: resumeAt)
        if wasPlaying { play() }
    }

    // MARK: - Observation setup

    private func observeItem(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    if case .loading = self.state { self.state = .ready }
                case .failed:
                    self.state = .failed(self.playbackErrorMessage(for: item))
                case .unknown:
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
                    self.state = .buffering
                }
            }
        }

        likelyToKeepUpObservation = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.isPlaybackLikelyToKeepUp, case .buffering = self.state {
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
                    self.state = .playing
                case .paused:
                    if case .ended = self.state { return }
                    if case .failed = self.state { return }
                    if case .buffering = self.state { return }
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
            Task { @MainActor in
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
