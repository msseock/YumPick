import SwiftUI

enum HomePath: Hashable {}

struct HomeTabView: View {
    @State private var path: [HomePath] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
        }
    }
}
