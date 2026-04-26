import SwiftUI

enum PickPath: Hashable {}

struct PickTabView: View {
    @State private var path: [PickPath] = []

    var body: some View {
        NavigationStack(path: $path) {
            PickView()
        }
    }
}
