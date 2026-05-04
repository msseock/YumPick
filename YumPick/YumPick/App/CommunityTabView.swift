import SwiftUI

enum ComposeMode: Hashable {
    case create
    case edit(PostDetail)
}

enum CommunityPath: Hashable {
    case detail(postId: String)
    case compose(ComposeMode)
    case search
    case userPosts(userId: String)
    case likedByMe
}

struct CommunityTabView: View {
    @Binding var path: [CommunityPath]

    var body: some View {
        NavigationStack(path: $path) {
            CommunityView()
                .navigationDestination(for: CommunityPath.self) { destination in
                    switch destination {
                    case .detail(let postId):
                        CommunityPostDetailView(postId: postId)
                    case .compose(let mode):
                        switch mode {
                        case .create:
                            CommunityComposeView(mode: .create)
                        case .edit(let post):
                            CommunityComposeView(mode: .edit(post), existingPost: post)
                        }
                    case .search:
                        Text("검색")                      // 7단계에서 교체
                    case .userPosts(let userId):
                        Text("유저 게시글: \(userId)")    // 8단계에서 교체
                    case .likedByMe:
                        Text("내 좋아요 게시글")          // 8단계에서 교체
                    }
                }
        }
    }
}
