import SwiftUI

enum YPFont {
    // MARK: - Helper
    private static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        return .custom("Pretendard-\(weight.rawValue)", size: size)
    }
    
    private enum PretendardWeight: String {
        case bold = "Bold"
        case medium = "Medium"
        case regular = "Regular"
    }

    // MARK: - Tokens
    /// 20px, Bold (화면 기본 타이틀)
    static let title1 = pretendard(.bold, size: 20)
    
    /// 16px, Bold
    static let body1Bold = pretendard(.bold, size: 16)
    /// 16px, Medium (기본 본문, 주요 정보)
    static let body1 = pretendard(.medium, size: 16)

    /// 14px, Bold
    static let body2Bold = pretendard(.bold, size: 14)
    /// 14px, Medium (보조 본문)
    static let body2 = pretendard(.medium, size: 14)

    /// 13px, Bold
    static let body3Bold = pretendard(.bold, size: 13)
    /// 13px, Medium (작은 본문)
    static let body3 = pretendard(.medium, size: 13)
    
    /// 12px, Regular (캡션, 상태 보조 텍스트)
    static let caption1 = pretendard(.regular, size: 12)
    
    /// 10px, Regular (아주 작은 보조 정보)
    static let caption2 = pretendard(.regular, size: 10)
    
    /// 8px, Regular (극소형 라벨)
    static let caption3 = pretendard(.regular, size: 8)
}

// SwiftUI View Modifier for easier usage
extension View {
    func ypFont(_ token: Font) -> some View {
        self.font(token)
    }
}
