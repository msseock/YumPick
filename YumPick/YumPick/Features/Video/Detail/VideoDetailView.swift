import SwiftUI

struct VideoDetailView: View {
    @State private var viewModel: VideoDetailViewModel
    @State private var showsControls = true
    @State private var isFullscreen = false

    private let relatedVideos: [Video]
    private let onDismiss: () -> Void

    private let relatedGridColumns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    init(video: Video, relatedVideos: [Video] = [], onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: VideoDetailViewModel(video: video))
        self.relatedVideos = relatedVideos
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
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    playerSection
                        .background(Color.black)
                        .frame(width: proxy.size.width)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)

                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(YP2Color.ink.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .padding(12)
                }

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                        actionRow
                        Rectangle()
                            .fill(YP2Color.borderDefault)
                            .frame(height: 1)
                        descriptionBlock
                        relatedVideosSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .frame(width: proxy.size.width, alignment: .leading)
                }
                .background(YP2Color.paper)
            }
            .background(YP2Color.paper)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.video.title)
                .font(.custom("Pretendard-Bold", size: 22))
                .foregroundStyle(YP2Color.ink)
                .multilineTextAlignment(.leading)

            Text("조회 \(formattedViewCount(viewModel.video.view_count)) · \(formattedDuration(viewModel.video.duration))")
                .font(.custom("Pretendard-Medium", size: 13))
                .foregroundStyle(YP2Color.textSecondary)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            likeChip

            Spacer()

            if !viewModel.availableSubtitles.isEmpty { subtitleMenu }
            if !viewModel.availableQualities.isEmpty { qualityMenu }
        }
    }

    private var likeChip: some View {
        Button {
            Task { await viewModel.toggleLike() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(viewModel.likeCount)")
                    .font(.custom("Pretendard-Bold", size: 13))
            }
            .foregroundStyle(viewModel.isLiked ? YP2Color.order : YP2Color.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(viewModel.isLiked ? YP2Color.ink : YP2Color.fog)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var descriptionBlock: some View {
        Text(viewModel.video.description)
            .font(.custom("Pretendard-Medium", size: 14))
            .foregroundStyle(YP2Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var relatedVideosSection: some View {
        if !relatedVideos.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("다른 영상도 보기")
                    .font(.custom("Pretendard-Bold", size: 18))
                    .foregroundStyle(YP2Color.ink)

                LazyVGrid(columns: relatedGridColumns, spacing: 10) {
                    ForEach(relatedVideos) { video in
                        YP2VideoShortCard(video: video)
                    }
                }
            }
            .padding(.top, 8)
        }
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
                ProgressView().tint(.white)
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
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(YP2Color.ink.opacity(0.55))
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
                ProgressView().tint(.white)
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
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(YP2Color.order)
            Text(message)
                .font(.custom("Pretendard-Medium", size: 13))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Button {
                Task { await viewModel.loadStream() }
            } label: {
                Text("다시 시도")
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(YP2Color.ink)
                    .padding(.horizontal, 22)
                    .frame(height: 40)
                    .background(YP2Color.order)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(YP2Color.ink.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func subtitleOverlay(bottomPadding: CGFloat) -> some View {
        if let text = viewModel.currentSubtitleText {
            VStack {
                Spacer()
                Text(text)
                    .font(.custom("Pretendard-Bold", size: 14))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(YP2Color.ink.opacity(0.6))
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
            chipLabel(icon: "captions.bubble", text: viewModel.selectedSubtitleLanguage ?? "자막")
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
            chipLabel(icon: "gearshape", text: viewModel.selectedQuality ?? "자동")
        }
    }

    private func chipLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.custom("Pretendard-Bold", size: 12))
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(YP2Color.ink)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .overlay(
            Capsule().stroke(YP2Color.borderSubtle, lineWidth: 1)
        )
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

    private func formattedViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
