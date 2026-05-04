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
}
