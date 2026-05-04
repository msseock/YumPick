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
