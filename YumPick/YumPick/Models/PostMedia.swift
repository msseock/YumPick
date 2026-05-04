import Foundation

enum PostMedia {
    case image(Data, fileName: String)
    case video(URL, thumbnail: Data?, fileName: String)

    var fileName: String {
        switch self {
        case .image(_, let name): return name
        case .video(_, _, let name): return name
        }
    }

    var mimeType: String {
        switch self {
        case .image: return "image/jpeg"
        case .video: return "video/mp4"
        }
    }

    var data: Data? {
        switch self {
        case .image(let data, _): return data
        case .video(let url, _, _): return try? Data(contentsOf: url)
        }
    }
}
