import Foundation

enum ChatFileKind {
    case image
    case gif
    case video
    case pdf
    case unknown

    static func detect(from path: String) -> ChatFileKind {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "webp":
            return .image
        case "gif":
            return .gif
        case "mp4", "mov", "m4v", "avi", "mkv", "wmv":
            return .video
        case "pdf":
            return .pdf
        default:
            return .unknown
        }
    }

    var isMedia: Bool {
        switch self {
        case .image, .gif, .video: return true
        case .pdf, .unknown:       return false
        }
    }
}

func isPDFPath(_ path: String) -> Bool {
    ChatFileKind.detect(from: path) == .pdf
}

extension Array where Element == String {
    func splitMediaAndPDF() -> (media: [String], pdfs: [String]) {
        var media: [String] = []
        var pdfs: [String] = []
        for path in self {
            switch ChatFileKind.detect(from: path) {
            case .pdf:
                pdfs.append(path)
            case .image, .gif, .video, .unknown:
                media.append(path)
            }
        }
        return (media, pdfs)
    }
}
