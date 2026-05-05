import SwiftUI

struct MediaLightboxView: View {
    let files: [String]
    @Binding var selectedIndex: Int?
    var namespace: Namespace.ID

    @State private var dragOffset: CGSize = .zero
    @State private var currentIndex: Int = 0
    @State private var dragDirection: DragDirection = .undetermined

    private let dismissThreshold: CGFloat = 150

    private enum DragDirection { case undetermined, vertical, horizontal }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(files.enumerated()), id: \.offset) { idx, path in
                    Group {
                        if isVideoPath(path) {
                            VideoPlayerView(path: path, autoPlay: idx == currentIndex)
                                .matchedGeometryEffect(id: path, in: namespace)
                        } else {
                            CachedImage(path: path)
                                .scaledToFit()
                                .matchedGeometryEffect(id: path, in: namespace)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: files.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .offset(dragOffset)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 50)
                }
                Spacer()
            }
        }
        .onAppear {
            currentIndex = selectedIndex ?? 0
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let dx = abs(value.translation.width)
                    let dy = value.translation.height

                    // 첫 움직임에서 방향 확정, 이후 고정
                    if dragDirection == .undetermined {
                        if dx > abs(dy) {
                            dragDirection = .horizontal
                        } else if dy > 0 {
                            dragDirection = .vertical
                        }
                    }

                    if dragDirection == .vertical {
                        dragOffset = CGSize(width: 0, height: max(0, dy))
                    }
                }
                .onEnded { value in
                    defer { dragDirection = .undetermined }

                    if dragDirection == .vertical,
                       value.translation.height > dismissThreshold {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }

    private var backgroundOpacity: Double {
        let progress = min(1, dragOffset.height / 400)
        return 1 - progress * 0.6
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedIndex = nil
            dragOffset = .zero
        }
    }
}
