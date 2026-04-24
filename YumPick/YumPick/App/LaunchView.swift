import SwiftUI

struct LaunchView: View {
    var body: some View {
        ZStack {
            YPColor.backgroundPrimary.ignoresSafeArea()
            ProgressView()
                .tint(YPColor.actionPrimary)
        }
    }
}
