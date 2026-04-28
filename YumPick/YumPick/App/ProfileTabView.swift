import SwiftUI

enum ProfilePath: Hashable {}

struct ProfileTabView: View {
    @Binding var path: [ProfilePath]

    var body: some View {
        NavigationStack(path: $path) {
            ProfileView()
        }
    }
}
