import SwiftUI

enum ProfilePath: Hashable {}

struct ProfileTabView: View {
    @State private var path: [ProfilePath] = []

    var body: some View {
        NavigationStack(path: $path) {
            ProfileView()
        }
    }
}
