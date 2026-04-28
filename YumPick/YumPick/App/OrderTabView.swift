import SwiftUI

enum OrderPath: Hashable {}

struct OrderTabView: View {
    @Binding var path: [OrderPath]

    var body: some View {
        NavigationStack(path: $path) {
            OrderView()
        }
    }
}
