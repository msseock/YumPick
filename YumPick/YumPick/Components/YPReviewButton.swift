import SwiftUI

enum YPReviewButtonState {
    case `default`
    case reviewed(rating: Double)
}

struct YPReviewButton: View {
    var state: YPReviewButtonState
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                switch state {
                case .default:
                    Text("리뷰 작성")
                        .font(YPFont.body1)
                        .foregroundStyle(YPColor.borderDefault)

                case .reviewed(let rating):
                    Image("Star_Fill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(YPColor.actionAccent)

                    Text(String(format: "%.1f", rating))
                        .font(YPFont.body1)
                        .foregroundStyle(YPColor.textSecondary)
                }
            }
            .frame(width: 318, height: 40)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(YPColor.borderSubtle, lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        YPReviewButton(state: .default, action: {})
        YPReviewButton(state: .reviewed(rating: 4.5), action: {})
    }
    .padding()
}
