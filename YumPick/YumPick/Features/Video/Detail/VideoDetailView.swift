import SwiftUI

struct VideoDetailView: View {
    @State private var viewModel: VideoDetailViewModel
    @State private var showsControls = true

    init(video: Video) {
        _viewModel = State(initialValue: VideoDetailViewModel(video: video))
    }

    var body: some View {
        VStack(spacing: 0) {
            playerSection
                .background(Color.black)
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.video.title)
                        .font(YPFont.title1)
                        .foregroundStyle(YPColor.textPrimary)

                    HStack(spacing: 12) {
                        Label("\(viewModel.video.view_count)", systemImage: "eye")
                        Label("\(viewModel.video.like_count)", systemImage: "heart")
                        Spacer()
                        if !viewModel.availableSubtitles.isEmpty {
                            subtitleMenu
                        }
                        if !viewModel.availableQualities.isEmpty {
                            qualityMenu
                        }
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
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: playerStateKey(viewModel.player.state)) { _, newKey in
            if newKey == "failed" {
                Task { await viewModel.recoverFromPlaybackFailure() }
            }
        }
    }

    @ViewBuilder
    private var playerSection: some View {
        ZStack {
            HLSPlayerView(player: viewModel.player.player)
                .onTapGesture {
                    withAnimation { showsControls.toggle() }
                }

            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView().tint(YPColor.gray0)
            case .failed(let message):
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
            case .ready:
                if showsControls {
                    VStack {
                        Spacer()
                        PlayerControlsView(viewModel: viewModel.player)
                    }
                }
            }

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
                        .padding(.bottom, showsControls ? 64 : 16)
                        .padding(.horizontal, 16)
                }
                .allowsHitTesting(false)
            }
        }
    }

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
            Button {
                viewModel.toggleSubtitle()
            } label: {
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(YPColor.gray30, lineWidth: 1)
            )
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(YPColor.gray30, lineWidth: 1)
            )
        }
    }

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
