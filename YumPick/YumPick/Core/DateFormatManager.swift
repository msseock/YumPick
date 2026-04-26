import Foundation

class DateFormatManager {
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

    // ISO 8601 → "2025년 4월 26일 오후 3:00"
    func orderDate(from isoString: String) -> String {
        let date = isoParser.date(from: isoString)
            ?? isoParserNoFraction.date(from: isoString)
        guard let date else { return "" }
        return orderDateFormatter.string(from: date)
    }
}
