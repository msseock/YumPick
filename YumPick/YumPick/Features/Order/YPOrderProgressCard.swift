import SwiftUI

struct YPOrderProgressCard: View {
    var orderCode: String
    var shopName: String
    var paidAt: String
    var storeImagePath: String?
    var timeline: [OrderStatusTimeline]

    private enum StatusStep: CaseIterable {
        case pendingApproval, approved, inProgress, readyForPickup, pickedUp

        var key: String {
            switch self {
            case .pendingApproval:  return "PENDING_APPROVAL"
            case .approved:         return "APPROVED"
            case .inProgress:       return "IN_PROGRESS"
            case .readyForPickup:   return "READY_FOR_PICKUP"
            case .pickedUp:         return "PICKED_UP"
            }
        }

        var label: String {
            switch self {
            case .pendingApproval:  return "승인대기"
            case .approved:         return "주문승인"
            case .inProgress:       return "조리 중"
            case .readyForPickup:   return "픽업대기"
            case .pickedUp:         return "픽업완료"
            }
        }
    }

    private struct ResolvedStep {
        let label: String
        let completed: Bool
        let timeLabel: String?
    }

    private enum Metrics {
        static let timelineColumnWidth: CGFloat = 180
        static let timelineColumnHeight: CGFloat = 200
        static let timelineHorizontalPadding: CGFloat = 16
        static let timelineVerticalPadding: CGFloat = 17
        static let progressCircleSize: CGFloat = 16
    }

    private var resolvedSteps: [ResolvedStep] {
        let dict = Dictionary(uniqueKeysWithValues: timeline.map { ($0.status, $0) })
        return StatusStep.allCases.map { step in
            let entry = dict[step.key]
            let timeLabel = entry?.changedAt.flatMap {
                DateFormatManager.shared.pickupStatusTime(from: $0)
            }
            return ResolvedStep(
                label: step.label,
                completed: entry?.completed ?? false,
                timeLabel: timeLabel
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leftColumn
            timelineColumn
        }
        .padding(20)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color(red: 123/255, green: 120/255, blue: 134/255).opacity(0.08),
            radius: 6, x: 0, y: 4
        )
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("주문번호")
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
                Text(orderCode)
                    .font(YPFont.body3Bold)
                    .foregroundStyle(YPColor.textSecondary)
            }

            Text(shopName)
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
                .lineLimit(2)

            Text(DateFormatManager.shared.orderDate(from: paidAt))
                .font(YPFont.caption2)
                .foregroundStyle(YPColor.textTertiary)
                .lineLimit(2)

            Color.clear
                .frame(height: 8)

            storeImage
                .frame(maxWidth: .infinity, maxHeight: 120)
//                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var storeImage: some View {
        Group {
            if hasStoreImagePath {
                CachedImage(path: storeImagePath)
            } else {
                Image("donut")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var hasStoreImagePath: Bool {
        guard let path = storeImagePath?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return !path.isEmpty
    }

    private var timelineColumn: some View {
        GeometryReader { proxy in
            let connectorHeight = timelineConnectorHeight(in: proxy.size.height)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(resolvedSteps.enumerated()), id: \.offset) { index, step in
                    timelineRow(
                        step: step,
                        connectorColor: connectorColor(after: index),
                        connectorHeight: connectorHeight,
                        isLast: index == resolvedSteps.count - 1
                    )
                }
            }
            .padding(.horizontal, Metrics.timelineHorizontalPadding)
            .padding(.vertical, Metrics.timelineVerticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(width: Metrics.timelineColumnWidth, height: Metrics.timelineColumnHeight)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func timelineRow(
        step: ResolvedStep,
        connectorColor: Color,
        connectorHeight: CGFloat,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                YPProgressCircle(isFinished: step.completed)

                if !isLast {
                    Rectangle()
                        .fill(connectorColor)
                        .frame(width: 4, height: connectorHeight)
                }
            }
            .frame(width: 16)

            Text(step.label)
                .font(YPFont.body3Bold)
                .foregroundStyle(
                    step.completed ? YPColor.textPrimary : YPColor.textTertiary
                )

            Spacer()

            if let time = step.timeLabel {
                Text(time)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
            }
        }
    }

    private func timelineConnectorHeight(in columnHeight: CGFloat) -> CGFloat {
        let contentHeight = columnHeight - Metrics.timelineVerticalPadding * 2
        let circleHeight = Metrics.progressCircleSize * CGFloat(resolvedSteps.count)
        let connectorCount = max(resolvedSteps.count - 1, 1)

        return max((contentHeight - circleHeight) / CGFloat(connectorCount), 0)
    }

    private func connectorColor(after index: Int) -> Color {
        guard resolvedSteps.indices.contains(index + 1) else {
            return .clear
        }

        return resolvedSteps[index + 1].completed
            ? YPColor.brandBlackSprout
            : YPColor.borderSubtle
    }
}

#Preview {
    VStack(spacing: 16) {
        YPOrderProgressCard(
            orderCode: "A4922",
            shopName: "새싹 도넛 가게",
            paidAt: "2025-04-22T09:20:00.000Z",
            storeImagePath: nil,
            timeline: [
                OrderStatusTimeline(status: "PENDING_APPROVAL", completed: true,  changedAt: "2025-04-22T09:24:00.000Z"),
                OrderStatusTimeline(status: "APPROVED",          completed: true,  changedAt: "2025-04-22T09:27:00.000Z"),
                OrderStatusTimeline(status: "IN_PROGRESS",       completed: true,  changedAt: "2025-04-22T09:36:00.000Z"),
                OrderStatusTimeline(status: "READY_FOR_PICKUP",  completed: false, changedAt: nil),
                OrderStatusTimeline(status: "PICKED_UP",         completed: false, changedAt: nil),
            ]
        )
    }
    .padding()
    .background(YPColor.backgroundBrandSubtle)
}
