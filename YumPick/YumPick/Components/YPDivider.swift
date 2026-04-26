import SwiftUI

struct YPDivider: View {
    var body: some View {
        Rectangle()
            .fill(YPColor.borderSubtle)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    YPDivider()
        .padding()
}
