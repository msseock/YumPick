import Foundation

enum FixtureLoader {
    static let decoder: JSONDecoder = JSONDecoder()
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    static func decode<T: Decodable>(_ type: T.Type = T.self, from path: String) throws -> T {
        guard let url = FixtureFileResolver.dataURL(for: path) else {
            throw FixtureError.missingFixture(path)
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    static func decodeIfPresent<T: Decodable>(_ type: T.Type = T.self, from path: String) -> T? {
        try? decode(type, from: path)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}

enum FixtureError: LocalizedError {
    case missingFixture(String)
    case unsupportedWriteOperation

    var errorDescription: String? {
        switch self {
        case .missingFixture(let path):
            return "Fixture 파일을 찾을 수 없습니다: \(path).json"
        case .unsupportedWriteOperation:
            return "Fixture 모드에서는 쓰기 요청을 지원하지 않습니다."
        }
    }
}
