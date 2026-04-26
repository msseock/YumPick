import SwiftUI

struct PickView: View {
    @State private var viewModel = PickViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("픽업")
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
