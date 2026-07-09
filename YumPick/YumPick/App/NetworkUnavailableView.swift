import SwiftUI

struct NetworkUnavailableView: View {
    let isRetrying: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(YP2Color.actionInk)
                .frame(width: 72, height: 72)
                .background(YP2Color.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 8) {
                Text("네트워크 연결이 필요합니다")
                    .font(YPFont.title1)
                    .foregroundStyle(YPColor.textPrimary)

                Text("연결 상태를 확인한 뒤 다시 시도해주세요.")
                    .font(YPFont.body2)
                    .foregroundStyle(YPColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retry) {
                Group {
                    if isRetrying {
                        ProgressView()
                            .tint(YPColor.gray0)
                    } else {
                        Text("다시 시도")
                            .font(YPFont.body1)
                    }
                }
                .foregroundStyle(YP2Color.actionInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(YP2Color.actionPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .disabled(isRetrying)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(YPColor.backgroundPrimary)
    }
}

#Preview("Default") {
    NetworkUnavailableView(isRetrying: false) {
        print("Retry tapped")
    }
}

#Preview("Retrying") {
    NetworkUnavailableView(isRetrying: true) {
        print("Retry tapped")
    }
}
