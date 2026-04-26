import SwiftUI

struct OrderView: View {
    @State private var viewModel = OrderViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("주문")
                    .font(YPFont.title1)
                    .foregroundStyle(YPColor.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await viewModel.fetchContent()
        }
    }
}
