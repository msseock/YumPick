import SwiftUI

struct YPCheckBox: View {
    var isChecked: Bool

    var body: some View {
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

#Preview {
    HStack(spacing: 24) {
        YPCheckBox(isChecked: false)
        YPCheckBox(isChecked: true)
    }
    .padding()
}
