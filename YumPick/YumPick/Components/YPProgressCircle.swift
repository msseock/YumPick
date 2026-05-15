import SwiftUI

struct YPProgressCircle: View {
    var isFinished: Bool

    var body: some View {
        ZStack {
            if isFinished {
                Circle()
                    .fill(YP2Color.order)
                    .frame(width: 16, height: 16)
                Image("Check")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(YP2Color.backgroundPrimary)
            } else {
                Circle()
                    .strokeBorder(YP2Color.borderSubtle, lineWidth: 4)
                    .frame(width: 16, height: 16)
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        YPProgressCircle(isFinished: false)
        YPProgressCircle(isFinished: true)
    }
    .padding()
}
