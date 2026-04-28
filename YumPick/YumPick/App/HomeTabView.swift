import SwiftUI

enum HomePath: Hashable {}

struct HomeTabView: View {
    @Binding var path: [HomePath]

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
        }
    }
}
