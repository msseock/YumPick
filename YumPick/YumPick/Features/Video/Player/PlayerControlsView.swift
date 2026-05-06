import SwiftUI

struct PlayerControlsView: View {
    @Bindable var viewModel: VideoPlayerViewModel
    let isFullscreen: Bool
    let onToggleFullscreen: () -> Void

    @State private var isScrubbing: Bool = false
    @State private var scrubValue: Double = 0

    init(
        viewModel: VideoPlayerViewModel,
        isFullscreen: Bool = false,
        onToggleFullscreen: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.isFullscreen = isFullscreen
        self.onToggleFullscreen = onToggleFullscreen
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button {
                    viewModel.togglePlay()
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(YPColor.gray0)
                }

                Text(formattedTime(displayedTime))
                    .font(YPFont.caption1.monospacedDigit())
                    .foregroundStyle(YPColor.gray0)

                progressBar

                Text(formattedTime(viewModel.duration))
                    .font(YPFont.caption1.monospacedDigit())
                    .foregroundStyle(YPColor.gray0)

                Button {
                    viewModel.toggleMute()
                } label: {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(YPColor.gray0)
                }

                Button {
                    onToggleFullscreen()
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(YPColor.gray0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(LinearGradient(
                colors: [.clear, YPColor.gray100.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }

    private var playPauseIcon: String {
        if case .ended = viewModel.state {
            return "arrow.counterclockwise"
        }
        return viewModel.isPlaying ? "pause.fill" : "play.fill"
    }

    private var displayedTime: Double {
        isScrubbing ? scrubValue : viewModel.currentTime
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progress = viewModel.duration > 0 ? min(displayedTime / viewModel.duration, 1) : 0
            let buffered = viewModel.duration > 0 ? min(viewModel.bufferedTime / viewModel.duration, 1) : 0

            ZStack(alignment: .leading) {
                Capsule().fill(YPColor.gray0.opacity(0.25))
                Capsule().fill(YPColor.gray0.opacity(0.4))
                    .frame(width: width * buffered)
                Capsule().fill(YPColor.actionAccent)
                    .frame(width: width * progress)
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard viewModel.duration > 0, width > 0 else { return }
                        if !isScrubbing {
                            isScrubbing = true
                            scrubValue = viewModel.currentTime
                        }
                        let ratio = max(0, min(value.location.x / width, 1))
                        scrubValue = ratio * viewModel.duration
                    }
                    .onEnded { _ in
                        let target = scrubValue
                        Task {
                            await viewModel.seek(to: target)
                            isScrubbing = false
                        }
                    }
            )
        }
        .frame(height: 24)
    }

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
