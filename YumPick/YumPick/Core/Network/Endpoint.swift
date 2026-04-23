import Foundation

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var parameters: RequestParameters { get }
    var requiresAuthorization: Bool { get }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum RequestParameters {
    case query([String: String])
    case body(Encodable)
    case multipart([MultipartData])
    case none
}

struct MultipartData {
    let name: String
    let fileName: String?
    let mimeType: String
    let data: Data
}

extension Endpoint {
    var baseURL: String { SecretConstants.baseURL }
    var headers: [String: String] { ["SeSACKey": SecretConstants.sesacKey] }
    var requiresAuthorization: Bool { true }
}
