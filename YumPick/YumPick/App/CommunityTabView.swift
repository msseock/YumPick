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
    case chatRoom(String)
}

struct CommunityTabView: View {
    @Binding var path: [CommunityPath]

    var body: some View {
        NavigationStack(path: $path) {
            CommunityView()
                .navigationDestination(for: CommunityPath.self) { destination in
                    switch destination {
                    case .detail(let postId):
                        CommunityPostDetailView(postId: postId) { roomID in
                            path.append(.chatRoom(roomID))
                        }
                    case .compose(let mode):
                        switch mode {
                        case .create:
                            CommunityComposeView(mode: .create)
                        case .edit(let post):
                            CommunityComposeView(mode: .edit(post), existingPost: post)
                        }
                    case .search:
                        CommunitySearchView()
                    case .userPosts(let userId):
                        CommunityPostListView(title: "작성한 게시글", mode: .userPosts(userId: userId))
                    case .likedByMe:
                        CommunityPostListView(title: "좋아요한 게시글", mode: .likedByMe)
                    case .chatRoom(let roomID):
                        ChatView(roomID: roomID)
                    }
                }
        }
    }
}
