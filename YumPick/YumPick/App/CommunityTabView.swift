import SwiftUI

enum CommunityPath: Hashable {}

struct CommunityTabView: View {
    @State private var path: [CommunityPath] = []

    var body: some View {
        NavigationStack(path: $path) {
            CommunityView()
        }
    }
}
