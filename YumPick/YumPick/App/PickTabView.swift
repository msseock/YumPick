import SwiftUI

enum PickPath: Hashable {}

struct PickTabView: View {
    @Binding var path: [PickPath]

    var body: some View {
        NavigationStack(path: $path) {
            PickView()
        }
    }
}
