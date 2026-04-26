import SwiftUI

struct YPCheckBoxButton: View {
    var isChecked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isChecked ? YPColor.brandBlackSprout : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isChecked ? YPColor.brandBlackSprout : YPColor.brandBrightSprout, lineWidth: 1)
                    )
                    .frame(width: 16, height: 16)

                Image("Check")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(isChecked ? YPColor.backgroundPrimary : YPColor.brandBrightSprout)
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        YPCheckBoxButton(isChecked: false, action: {})
        YPCheckBoxButton(isChecked: true, action: {})
    }
    .padding()
}
