import SwiftUI

enum PickPath: Hashable {
    case videoDetail(Video)
}

struct PickTabView: View {
    @Binding var path: [PickPath]

    var body: some View {
        NavigationStack(path: $path) {
            VideoListView { video in
                path.append(.videoDetail(video))
            }
            .navigationDestination(for: PickPath.self) { destination in
                switch destination {
                case .videoDetail(let video):
                    VideoDetailView(video: video)
                }
            }
        }
    }
}
