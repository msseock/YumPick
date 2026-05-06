import Foundation

// MARK: - Protocol

protocol VideoClientProtocol {
    func fetchVideos(next: String?, limit: Int?) async throws -> VideoPage
    func fetchStream(videoId: String) async throws -> StreamInfo
    func toggleLike(videoId: String, likeStatus: Bool) async throws -> Bool
}

// MARK: - Endpoints

private struct LikeRequestBody: Encodable {
    let like_status: Bool
}

private struct LikeResponse: Decodable {
    let like_status: Bool
}

private enum VideoEndpoint: Endpoint {
    case list(next: String?, limit: Int?)
    case stream(videoId: String)
    case like(videoId: String, likeStatus: Bool)

    var path: String {
        switch self {
        case .list: return "/v1/videos"
        case .stream(let videoId): return "/v1/videos/\(videoId)/stream"
        case .like(let videoId, _): return "/v1/videos/\(videoId)/like"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .stream: return .get
        case .like: return .post
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .list(let next, let limit):
            var dict: [String: String] = [:]
            if let next, !next.isEmpty { dict["next"] = next }
            if let limit { dict["limit"] = "\(limit)" }
            return dict.isEmpty ? .none : .query(dict)
        case .stream:
            return .none
        case .like(_, let likeStatus):
            return .body(LikeRequestBody(like_status: likeStatus))
        }
    }
}

// MARK: - Response DTOs

private struct VideoListResponseDTO: Decodable {
    let data: [Video]
    let next_cursor: String?
}

// MARK: - Real Implementation

final class VideoClient: VideoClientProtocol {
    func fetchVideos(next: String?, limit: Int?) async throws -> VideoPage {
        let response: VideoListResponseDTO = try await NetworkManager.shared
            .request(VideoEndpoint.list(next: next, limit: limit))
        return VideoPage(
            videos: response.data,
            nextCursor: response.next_cursor?.nilIfEmpty
        )
    }

    func fetchStream(videoId: String) async throws -> StreamInfo {
        try await NetworkManager.shared.request(VideoEndpoint.stream(videoId: videoId))
    }

    func toggleLike(videoId: String, likeStatus: Bool) async throws -> Bool {
        let response: LikeResponse = try await NetworkManager.shared
            .request(VideoEndpoint.like(videoId: videoId, likeStatus: likeStatus))
        return response.like_status
    }
}

// MARK: - Mock

final class MockVideoClient: VideoClientProtocol {
    var fetchVideosResult: Result<VideoPage, Error> = .success(VideoPage(videos: [], nextCursor: nil))
    var fetchStreamResult: Result<StreamInfo, Error> = .failure(NetworkError.unknown)
    var toggleLikeResult: Result<Bool, Error> = .success(true)

    func fetchVideos(next: String?, limit: Int?) async throws -> VideoPage {
        try fetchVideosResult.get()
    }

    func fetchStream(videoId: String) async throws -> StreamInfo {
        try fetchStreamResult.get()
    }

    func toggleLike(videoId: String, likeStatus: Bool) async throws -> Bool {
        try toggleLikeResult.get()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
