import Foundation

struct StreamInfo: Codable, Hashable {
    let video_id: String
    let stream_url: String
    let qualities: [Quality]
    let subtitles: [Subtitle]

    struct Quality: Codable, Hashable {
        let quality: String
        let url: String
    }

    struct Subtitle: Codable, Hashable {
        let language: String
        let name: String
        let is_default: Bool
        let url: String
    }
}
