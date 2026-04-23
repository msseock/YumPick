import Foundation

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized           // 401 - 유효하지 않은 액세스 토큰
    case forbidden              // 403 - 접근 권한 없음
    case tokenExpired           // 419 - 액세스 토큰 만료 → 자동 갱신
    case refreshTokenExpired    // 418 - 리프레시 토큰 만료 → 로그아웃
    case invalidKey             // 420 - 유효하지 않은 SeSACKey
    case rateLimited            // 429 - API 호출 횟수 초과
    case invalidRequest         // 444 - 비정상 API 호출
    case clientError(Int)       // 400~499 (위 케이스 외)
    case serverError            // 500~599
    case decodingError
    case unknown
}
