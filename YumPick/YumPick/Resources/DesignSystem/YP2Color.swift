import SwiftUI

/// 얌픽 v2.0 디자인 시스템 색상 토큰.
/// "29CM-inspired editorial: 흑백 베이스, 옐로우는 CTA에만" 원칙을 따른다.
enum YP2Color {
    // MARK: - Core
    static let ink     = Color(hex: "#111111")
    static let paper   = Color(hex: "#FFFFFF")
    static let fog     = Color(hex: "#F4F4F4")
    static let order   = Color(hex: "#FFD84D")

    // MARK: - Surface
    static let backgroundPrimary   = paper
    static let backgroundSecondary = fog

    // MARK: - Text
    static let textPrimary   = ink
    static let textSecondary = Color(hex: "#666666")
    static let textTertiary  = Color(hex: "#888888")
    static let textMuted     = Color(hex: "#777777")

    // MARK: - Border
    static let borderDefault = Color(hex: "#EEEEEE")
    static let borderSubtle  = Color(hex: "#DDDDDD")

    // MARK: - Action
    static let actionPrimary = order
    static let actionInk     = ink

    // MARK: - Overlay (이미지 위 텍스트용)
    static let overlay        = Color.black.opacity(0.65)
    static let overlayStrong  = Color.black.opacity(0.75)

    // MARK: - 보조
    static let accentGreen = Color(hex: "#16833C")
}
