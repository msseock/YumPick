import Foundation

// MARK: - Protocol

protocol StoreDetailClientProtocol {
    func fetchStoreDetail(storeId: String) async throws -> StoreDetail
    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool
}

// MARK: - Endpoints

private enum StoreDetailEndpoint: Endpoint {
    case detail(storeId: String)
    case like(storeId: String, likeStatus: Bool)

    var path: String {
        switch self {
        case .detail(let storeId): return "/v1/stores/\(storeId)"
        case .like(let storeId, _): return "/v1/stores/\(storeId)/like"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .detail: return .get
        case .like: return .post
        }
    }

    var parameters: RequestParameters {
        switch self {
        case .detail: return .none
        case .like(_, let likeStatus): return .body(LikeRequestBody(like_status: likeStatus))
        }
    }

    var requiresAuthorization: Bool { true }
}

// MARK: - Request / Response DTOs

private struct LikeRequestBody: Encodable {
    let like_status: Bool
}

private struct LikeStoreResponse: Decodable {
    let like_status: Bool
}

// MARK: - Real Implementation

final class StoreDetailClient: StoreDetailClientProtocol {
    func fetchStoreDetail(storeId: String) async throws -> StoreDetail {
        try await NetworkManager.shared.request(StoreDetailEndpoint.detail(storeId: storeId))
    }

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        let response: LikeStoreResponse = try await NetworkManager.shared
            .request(StoreDetailEndpoint.like(storeId: storeId, likeStatus: likeStatus))
        return response.like_status
    }
}

// MARK: - Mock

final class MockStoreDetailClient: StoreDetailClientProtocol {
    var fetchStoreDetailResult: Result<StoreDetail, Error> = .success(.mock)
    var toggleLikeResult: Result<Bool, Error> = .success(true)

    func fetchStoreDetail(storeId: String) async throws -> StoreDetail {
        try fetchStoreDetailResult.get()
    }

    func toggleLike(storeId: String, likeStatus: Bool) async throws -> Bool {
        try toggleLikeResult.get()
    }
}

// MARK: - Mock Data

extension StoreDetail {
    static let mock = StoreDetail(
        store_id: "mock-store-id",
        category: "디저트",
        name: "새싹 도넛 가게",
        description: "신선한 재료로 만든 수제 도넛 전문점",
        hashTags: ["#수제도넛", "#신선한재료", "#데일리디저트"],
        open: "10:00 AM",
        close: "07:00 PM",
        address: "서울 영등포구 선유로9길 30 106동",
        estimated_pickup_time: 30,
        parking_guide: "매장 앞 평행 주차 가능",
        store_image_urls: [],
        is_picchelin: true,
        is_pick: false,
        pick_count: 202,
        total_review_count: 211,
        total_order_count: 135,
        total_rating: 4.8,
        creator: UserInfo(user_id: "creator-id", nick: "운영자", profileImage: nil),
        geolocation: Geolocation(longitude: 126.896_3, latitude: 37.522_1),
        menu_list: [
            StoreMenu(
                menu_id: "menu-1", store_id: "mock-store-id",
                category: "인기메뉴", name: "올리브 그린 새싹 도넛",
                description: "겉은 바삭하고 속은 촉촉하며, 한 입 베어물면 향긋한 허브향이 입 안 가득 퍼집니다.",
                origin_information: nil, price: 3200, is_sold_out: false,
                tags: ["인기 1위"], menu_image_url: nil,
                createdAt: "", updatedAt: ""
            ),
            StoreMenu(
                menu_id: "menu-2", store_id: "mock-store-id",
                category: "인기메뉴", name: "올리브 쥬이시티 도넛",
                description: "올리브 오일을 듬뿍 사용한 반죽은 고소하면서도, 손으로 찢어먹는 재미까지 느낄 수 있어요.",
                origin_information: nil, price: 3700, is_sold_out: true,
                tags: ["인기 2위"], menu_image_url: nil,
                createdAt: "", updatedAt: ""
            ),
            StoreMenu(
                menu_id: "menu-3", store_id: "mock-store-id",
                category: "수제도넛", name: "레몬 민트 새싹 도넛",
                description: "유기농 레몬 제스트와 민트를 넣은 반죽에, 새싹채소를 더해 초록빛 생기를 입혔습니다.",
                origin_information: nil, price: 3600, is_sold_out: false,
                tags: ["인기 2위"], menu_image_url: nil,
                createdAt: "", updatedAt: ""
            ),
            StoreMenu(
                menu_id: "menu-4", store_id: "mock-store-id",
                category: "수제도넛", name: "팜핑 새싹 도넛",
                description: nil, origin_information: nil, price: 3400, is_sold_out: false,
                tags: ["인기 3위"], menu_image_url: nil,
                createdAt: "", updatedAt: ""
            )
        ],
        createdAt: "", updatedAt: ""
    )
}
