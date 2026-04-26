import SwiftUI

struct LazyTabView<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            if hasLoaded {
                content()
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(isSelected)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isSelected, initial: true) { _, newValue in
            if newValue { hasLoaded = true }
        }
    }
}
