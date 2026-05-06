import SwiftUI

struct VideoDetailView: View {
    @State private var viewModel: VideoDetailViewModel
    @State private var showsControls = true
    @State private var isFullscreen = false

    private let onDismiss: () -> Void

    init(video: Video, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: VideoDetailViewModel(video: video))
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isFullscreen {
                fullscreenContent
            } else {
                portraitContent
            }
        }
        .interactiveDismissDisabled()
        .task { await viewModel.onAppear() }
        .onDisappear {
            viewModel.onDisappear()
            OrientationManager.shared.lockPortrait()
        }
        .onChange(of: playerStateKey(viewModel.player.state)) { _, newKey in
            if newKey == "failed" {
                Task { await viewModel.recoverFromPlaybackFailure() }
            }
        }
    }

    // MARK: - Portrait layout

    private var portraitContent: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                playerSection
                    .background(Color.black)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .padding(10)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.video.title)
                        .font(YPFont.title1)
                        .foregroundStyle(YPColor.textPrimary)

                    HStack(spacing: 12) {
                        Label("\(viewModel.video.view_count)", systemImage: "eye")
                        Button {
                            Task { await viewModel.toggleLike() }
                        } label: {
                            Label("\(viewModel.likeCount)", systemImage: viewModel.isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(viewModel.isLiked ? YPColor.actionAccent : YPColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if !viewModel.availableSubtitles.isEmpty { subtitleMenu }
                        if !viewModel.availableQualities.isEmpty { qualityMenu }
                    }
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textSecondary)

                    Divider()

                    Text(viewModel.video.description)
                        .font(YPFont.body2)
                        .foregroundStyle(YPColor.textSecondary)
                }
                .padding(16)
            }
            .background(YPColor.backgroundPrimary)
        }
        .background(YPColor.backgroundPrimary)
    }

    // MARK: - Fullscreen layout

    private var fullscreenContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HLSPlayerView(player: viewModel.player.player)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { withAnimation { showsControls.toggle() } }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.height > 80 || value.velocity.height > 600 {
                                exitFullscreen()
                            }
                        }
                )

            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView().tint(YPColor.gray0)
            case .failed(let message):
                errorOverlay(message: message)
            case .ready:
                EmptyView()
            }

            subtitleOverlay(bottomPadding: showsControls ? 64 : 16)

            if showsControls {
                VStack {
                    HStack {
                        Spacer()
                        Button { exitFullscreen() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(YPColor.gray0)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(20)
                    }
                    Spacer()
                    PlayerControlsView(
                        viewModel: viewModel.player,
                        isFullscreen: true,
                        onToggleFullscreen: exitFullscreen
                    )
                        .padding(.bottom, 8)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }

    // MARK: - Player section (portrait)

    @ViewBuilder
    private var playerSection: some View {
        ZStack {
            HLSPlayerView(player: viewModel.player.player)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { showsControls.toggle() } }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let dy = value.translation.height
                            let vy = value.velocity.height
                            if dy > 80 || vy > 600 {
                                onDismiss()
                            } else if dy < -60 || vy < -600 {
                                enterFullscreen()
                            }
                        }
                )

            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView().tint(YPColor.gray0)
            case .failed(let message):
                errorOverlay(message: message)
            case .ready:
                EmptyView()
            }

            if showsControls {
                VStack {
                    Spacer()
                    PlayerControlsView(
                        viewModel: viewModel.player,
                        isFullscreen: false,
                        onToggleFullscreen: enterFullscreen
                    )
                }
            }

            subtitleOverlay(bottomPadding: showsControls ? 64 : 16)
        }
    }

    // MARK: - Shared subviews

    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(YPColor.actionAccent)
            Text(message)
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.gray0)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button("다시 시도") {
                Task { await viewModel.loadStream() }
            }
            .font(YPFont.body3Bold)
            .foregroundStyle(YPColor.gray0)
        }
    }

    @ViewBuilder
    private func subtitleOverlay(bottomPadding: CGFloat) -> some View {
        if let text = viewModel.currentSubtitleText {
            VStack {
                Spacer()
                Text(text)
                    .font(YPFont.body2Bold)
                    .foregroundStyle(YPColor.gray0)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(YPColor.gray100.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(.bottom, bottomPadding)
                    .padding(.horizontal, 16)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Actions

    private func enterFullscreen() {
        showsControls = true
        isFullscreen = true
        OrientationManager.shared.lockLandscape()
    }

    private func exitFullscreen() {
        isFullscreen = false
        OrientationManager.shared.lockPortrait()
    }

    // MARK: - Menus

    private var subtitleMenu: some View {
        Menu {
            Button {
                Task { await viewModel.selectSubtitle(language: nil) }
            } label: {
                if viewModel.selectedSubtitleLanguage == nil {
                    Label("자막 없음", systemImage: "checkmark")
                } else {
                    Text("자막 없음")
                }
            }
            ForEach(viewModel.availableSubtitles, id: \.language) { sub in
                Button {
                    Task { await viewModel.selectSubtitle(language: sub.language) }
                } label: {
                    if viewModel.selectedSubtitleLanguage == sub.language {
                        Label(sub.name, systemImage: "checkmark")
                    } else {
                        Text(sub.name)
                    }
                }
            }
            Divider()
            Button { viewModel.toggleSubtitle() } label: {
                Text(viewModel.isSubtitleEnabled ? "자막 끄기" : "자막 켜기")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "captions.bubble")
                Text(viewModel.selectedSubtitleLanguage ?? "자막")
            }
            .font(YPFont.caption1)
            .foregroundStyle(YPColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(YPColor.gray30, lineWidth: 1))
        }
    }

    private var qualityMenu: some View {
        Menu {
            Button {
                Task { await viewModel.selectQuality(nil) }
            } label: {
                if viewModel.selectedQuality == nil {
                    Label("자동", systemImage: "checkmark")
                } else {
                    Text("자동")
                }
            }
            ForEach(viewModel.availableQualities, id: \.self) { q in
                Button {
                    Task { await viewModel.selectQuality(q) }
                } label: {
                    if viewModel.selectedQuality == q {
                        Label(q, systemImage: "checkmark")
                    } else {
                        Text(q)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gearshape")
                Text(viewModel.selectedQuality ?? "자동")
            }
            .font(YPFont.caption1)
            .foregroundStyle(YPColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(YPColor.gray30, lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func playerStateKey(_ state: VideoPlayerViewModel.PlaybackState) -> String {
        switch state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .ready: return "ready"
        case .playing: return "playing"
        case .paused: return "paused"
        case .buffering: return "buffering"
        case .ended: return "ended"
        case .failed: return "failed"
        }
    }
}
