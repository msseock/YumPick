import SwiftUI

struct YPLikeButton: View {
    var isLiked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(isLiked ? "Like_Fill" : "Like_Empty")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(isLiked ? YPColor.brandBlackSprout : YPColor.borderDefault)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        YPLikeButton(isLiked: false, action: {})
        YPLikeButton(isLiked: true, action: {})
    }
    .padding()
}
