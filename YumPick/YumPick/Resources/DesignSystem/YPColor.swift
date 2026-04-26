import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum YPColor {
    // MARK: - Brand Colors
    static let brandBlackSprout = Color(hex: "#91A38B")
    static let brandDeepSprout = Color(hex: "#B7C8B1")
    static let brandBrightSprout = Color(hex: "#E0E4D9")
    static let brandBrightForsythia = Color(hex: "#FDC020")
    
    // MARK: - GrayScale
    static let gray0 = Color(hex: "#FFFFFF")
    static let gray15 = Color(hex: "#F9F9F9")
    static let gray30 = Color(hex: "#EAEAEA")
    static let gray45 = Color(hex: "#D8D6D7")
    static let gray60 = Color(hex: "#ABABAE")
    static let gray75 = Color(hex: "#6A6A6E")
    static let gray90 = Color(hex: "#434347")
    static let gray100 = Color(hex: "#0B0B0B")
    
    // MARK: - Semantic Colors
    static let backgroundPrimary = gray0
    static let backgroundSecondary = gray15
    static let backgroundBrandSubtle = brandBrightSprout
    
    static let textPrimary = gray100
    static let textSecondary = gray75
    static let textTertiary = gray60
    
    static let borderDefault = gray45
    static let borderSubtle = gray30
    
    static let actionPrimary = brandBlackSprout
    static let actionPrimaryPressed = brandDeepSprout
    static let actionAccent = brandBrightForsythia
}

// MARK: - 추가 색상
extension YPColor {
    static let brandBlackSproutDeep = Color(hex: "#82957B")
}
