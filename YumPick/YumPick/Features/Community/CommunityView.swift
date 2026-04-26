import SwiftUI

struct CommunityView: View {
    @State private var viewModel = CommunityViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("커뮤니티")
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
