import Foundation

struct SubtitleCue: Hashable {
    let start: Double
    let end: Double
    let text: String
}

enum WebVTTParser {
    static func parse(_ source: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard !lines.isEmpty else { continue }

            // 첫 줄이 cue identifier일 수도, timing line일 수도 있다.
            var index = 0
            // WEBVTT 헤더 스킵
            if lines[0].hasPrefix("WEBVTT") { continue }
            if lines.count > 1 && !lines[0].contains("-->") {
                index = 1
            }
            guard index < lines.count else { continue }

            let timing = lines[index]
            guard timing.contains("-->") else { continue }
            guard let (start, end) = parseTiming(timing) else { continue }

            let textLines = lines.dropFirst(index + 1)
            let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(start: start, end: end, text: text))
        }
        return cues.sorted { $0.start < $1.start }
    }

    private static func parseTiming(_ line: String) -> (Double, Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        // end 부분 뒤에 cue settings가 붙을 수 있다 → 첫 토큰만
        let endStr = parts[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
        guard let start = parseTimestamp(startStr), let end = parseTimestamp(endStr) else { return nil }
        return (start, end)
    }

    /// HH:MM:SS.mmm 또는 MM:SS.mmm
    private static func parseTimestamp(_ s: String) -> Double? {
        let segments = s.split(separator: ":")
        guard !segments.isEmpty else { return nil }
        let last = segments.last!
        let lastParts = last.split(separator: ".")
        guard let secInt = Double(lastParts[0]) else { return nil }
        let millis: Double = lastParts.count > 1 ? (Double(lastParts[1]) ?? 0) / pow(10, Double(lastParts[1].count)) : 0

        var seconds = secInt + millis
        if segments.count >= 2, let m = Double(segments[segments.count - 2]) {
            seconds += m * 60
        }
        if segments.count >= 3, let h = Double(segments[segments.count - 3]) {
            seconds += h * 3600
        }
        return seconds
    }
}
