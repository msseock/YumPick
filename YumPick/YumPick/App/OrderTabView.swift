import SwiftUI

enum OrderPath: Hashable {}

struct OrderTabView: View {
    @State private var path: [OrderPath] = []

    var body: some View {
        NavigationStack(path: $path) {
            OrderView()
        }
    }
}
