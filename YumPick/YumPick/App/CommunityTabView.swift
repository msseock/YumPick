import SwiftUI

enum CommunityPath: Hashable {}

struct CommunityTabView: View {
    @Binding var path: [CommunityPath]

    var body: some View {
        NavigationStack(path: $path) {
            CommunityView()
        }
    }
}
