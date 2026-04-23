import Foundation

enum HTTPStatusCode: Int {
    // 2xx
    case ok      = 200
    case created = 201

    // 4xx
    case badRequest            = 400
    case unauthorized          = 401
    case forbidden             = 403
    case refreshTokenExpired   = 418
    case tokenExpired          = 419
    case invalidKey            = 420
    case rateLimited           = 429
    case invalidRequest        = 444

    // 5xx
    case serverError = 500

    var isSuccess: Bool { (200..<300).contains(rawValue) }
}
