import Foundation

final class DateFormatManager {
    static let shared = DateFormatManager()

    private init() { }

    private let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoParserNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // 서버 두 번째 포맷: "yyyy-MM-dd HH:mm:ss.SSS Z"
    private let chatSpaceParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let chatISOFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let chatTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private let chatDateLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f
    }()

    private let orderDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    private let statusTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f
    }()

    private func date(from isoString: String) -> Date? {
        isoParser.date(from: isoString)
            ?? isoParserNoFraction.date(from: isoString)
    }

    // MARK: - Chat

    func date(fromChatISOString value: String) -> Date? {
        isoParser.date(from: value)
            ?? isoParserNoFraction.date(from: value)
            ?? chatSpaceParser.date(from: value)
    }

    func chatISOString(from date: Date) -> String {
        chatISOFormatter.string(from: date)
    }

    func chatTime(from date: Date) -> String {
        chatTimeFormatter.string(from: date)
    }

    func chatDateLabel(from date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "오늘" }
        if cal.isDateInYesterday(date) { return "어제" }
        return chatDateLabelFormatter.string(from: date)
    }

    // MARK: - Existing

    // ISO 8601 → "2025년 4월 26일 오후 3:00"
    func orderDate(from isoString: String) -> String {
        guard let date = date(from: isoString) else { return "" }
        return orderDateFormatter.string(from: date)
    }

    // ISO 8601 → "오후 6:24"
    func pickupStatusTime(from isoString: String) -> String? {
        guard let date = date(from: isoString) else { return nil }
        return statusTimeFormatter.string(from: date)
    }

    // ISO 8601 → "방금 전", "3분 전", "2시간 전", "5일 전", "2025년 4월 26일"
    func relativeDate(from isoString: String) -> String {
        guard let date = date(from: isoString) else { return "" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        switch seconds {
        case ..<60:      return "방금 전"
        case ..<3600:    return "\(seconds / 60)분 전"
        case ..<86400:   return "\(seconds / 3600)시간 전"
        case ..<2592000: return "\(seconds / 86400)일 전"
        default:         return orderDateFormatter.string(from: date)
        }
    }
}
