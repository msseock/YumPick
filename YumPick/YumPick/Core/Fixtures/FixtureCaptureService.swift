import Foundation

struct FixtureCaptureResult: Identifiable, Equatable {
    let id = UUID()
    let archiveURL: URL
    let successCount: Int
    let failureCount: Int
}

final class FixtureCaptureService {
    private let homeClient: HomeClientProtocol
    private let pickClient: PickClientProtocol
    private let orderClient: OrderClientProtocol
    private let communityClient: CommunityClientProtocol
    private let profileClient: ProfileClientProtocol
    private let chatClient: ChatClientProtocol
    private let storeDetailClient: StoreDetailClientProtocol
    private let reviewClient: ReviewClientProtocol
    private let videoClient: VideoClientProtocol
    private let locationManager: any LocationManagerProtocol
    private let assetRewriter: FixtureAssetRewriter
    private let exporter: FixtureArchiveExporter
    private let fileManager: FileManager

    private var manifest = FixtureManifest.make()
    private var snapshotRoot: URL?
    private var storeIDs = Set<String>()
    private var postIDs = Set<String>()
    private var roomIDs = Set<String>()
    private var videoIDs = Set<String>()
    private var popularSearches: [String] = []

    init(
        homeClient: HomeClientProtocol = HomeClient(),
        pickClient: PickClientProtocol = PickClient(),
        orderClient: OrderClientProtocol = OrderClient(),
        communityClient: CommunityClientProtocol = CommunityClient(),
        profileClient: ProfileClientProtocol = ProfileClient(),
        chatClient: ChatClientProtocol = ChatClient(),
        storeDetailClient: StoreDetailClientProtocol = StoreDetailClient(),
        reviewClient: ReviewClientProtocol = ReviewClient(),
        videoClient: VideoClientProtocol = VideoClient(),
        locationManager: any LocationManagerProtocol = LocationManager.shared,
        assetRewriter: FixtureAssetRewriter = FixtureAssetRewriter(),
        exporter: FixtureArchiveExporter = FixtureArchiveExporter(),
        fileManager: FileManager = .default
    ) {
        self.homeClient = homeClient
        self.pickClient = pickClient
        self.orderClient = orderClient
        self.communityClient = communityClient
        self.profileClient = profileClient
        self.chatClient = chatClient
        self.storeDetailClient = storeDetailClient
        self.reviewClient = reviewClient
        self.videoClient = videoClient
        self.locationManager = locationManager
        self.assetRewriter = assetRewriter
        self.exporter = exporter
        self.fileManager = fileManager
    }

    func capture() async throws -> FixtureCaptureResult {
        manifest = FixtureManifest.make()
        storeIDs.removeAll()
        postIDs.removeAll()
        roomIDs.removeAll()
        videoIDs.removeAll()
        popularSearches.removeAll()

        let root = try exporter.makeSnapshotRoot()
        snapshotRoot = root

        let geo = await locationManager.currentLocation() ?? Geolocation(longitude: 126.9780, latitude: 37.5665)

        await captureHome(geolocation: geo)
        await capturePick(geolocation: geo)
        await captureOrders()
        await captureCommunity(geolocation: geo)
        await captureProfile()
        await captureChat()
        await captureStoreDetailsAndReviews()
        await captureVideos()

        try await writeRawPayload(manifest, to: "manifest")
        let archiveURL = try exporter.zip(snapshotRoot: root)
        let failures = manifest.records.filter { $0.status == .failure }.count
        return FixtureCaptureResult(
            archiveURL: archiveURL,
            successCount: manifest.records.count - failures,
            failureCount: failures
        )
    }

    private func captureHome(geolocation: Geolocation) async {
        await writeStep("home/banners") {
            try await homeClient.fetchBanners()
        }
        await writeStep("home/popular_searches") {
            let searches = try await homeClient.fetchPopularSearches()
            popularSearches = searches
            return searches
        }
        await writeStep("home/popular_stores") {
            let stores = try await homeClient.fetchPopularStores(category: nil)
            collectStoreIDs(from: stores)
            return stores
        }
        for category in HomePopularCategory.allCases where category != .more {
            await writeStep("home/popular_stores_\(safeName(category.rawValue))") {
                let stores = try await homeClient.fetchPopularStores(category: category.title)
                collectStoreIDs(from: stores)
                return stores
            }
        }
        await writeStep("home/nearby_stores") {
            let page = try await homeClient.fetchNearbyStores(
                longitude: geolocation.longitude,
                latitude: geolocation.latitude,
                orderBy: HomeNearbySort.distance.rawValue,
                category: nil,
                next: nil
            )
            collectStoreIDs(from: page.stores)
            return page
        }
    }

    private func capturePick(geolocation: Geolocation) async {
        await writeStep("pick/nearby_stores") {
            let stores = try await pickClient.fetchNearbyStores(
                longitude: geolocation.longitude,
                latitude: geolocation.latitude,
                orderBy: HomeNearbySort.distance.rawValue
            )
            collectStoreIDs(from: stores)
            return stores
        }
    }

    private func captureOrders() async {
        await writeStep("order/orders") {
            let orders = try await orderClient.fetchOrders()
            collectStoreIDs(from: orders)
            return orders
        }
    }

    private func captureCommunity(geolocation: Geolocation) async {
        await writeStep("community/banners") {
            try await communityClient.fetchBanners()
        }
        await writeStep("community/geolocation_posts") {
            let page = try await communityClient.fetchGeolocationPosts(
                longitude: geolocation.longitude,
                latitude: geolocation.latitude,
                category: nil,
                orderBy: CommunityOrder.latest.rawValue,
                next: nil,
                limit: nil
            )
            collectPostIDs(from: page.posts)
            collectStoreIDs(from: page.posts)
            return page
        }
        if let term = popularSearches.first, !term.isEmpty {
            await writeStep("community/search_posts") {
                let posts = try await communityClient.searchPosts(title: term)
                collectPostIDs(from: posts)
                collectStoreIDs(from: posts)
                return posts
            }
        }
        for postID in Array(postIDs).prefix(10) {
            await writeStep("community/post_detail_\(safeName(postID))") {
                let detail = try await communityClient.fetchPostDetail(postId: postID)
                if let storeID = detail.store?.id { storeIDs.insert(storeID) }
                return detail
            }
        }
    }

    private func captureProfile() async {
        await writeStep("profile/my_profile") {
            try await profileClient.fetchMyProfile()
        }
    }

    private func captureChat() async {
        await writeStep("chat/rooms") {
            let rooms = try await chatClient.fetchRooms()
            roomIDs.formUnion(rooms.map(\.roomID))
            return rooms
        }
        for roomID in Array(roomIDs).prefix(10) {
            await writeStep("chat/messages_\(safeName(roomID))") {
                try await chatClient.fetchMessages(roomID: roomID, next: nil)
            }
        }
    }

    private func captureStoreDetailsAndReviews() async {
        for storeID in Array(storeIDs).prefix(10) {
            await writeStep("store/detail_\(safeName(storeID))") {
                try await storeDetailClient.fetchStoreDetail(storeId: storeID)
            }
            await writeStep("review/reviews_\(safeName(storeID))") {
                try await reviewClient.fetchReviews(storeId: storeID, next: nil, limit: nil, orderBy: nil)
            }
            await writeStep("review/ratings_\(safeName(storeID))") {
                try await reviewClient.fetchRatings(storeId: storeID)
            }
        }
    }

    private func captureVideos() async {
        await writeStep("video/videos") {
            let page = try await videoClient.fetchVideos(next: nil, limit: nil)
            videoIDs.formUnion(page.videos.map(\.video_id))
            return page
        }
        for videoID in Array(videoIDs).prefix(10) {
            await writeStep("video/stream_\(safeName(videoID))") {
                try await videoClient.fetchStream(videoId: videoID)
            }
        }
    }

    private func writeStep<T: Encodable>(_ path: String, operation: () async throws -> T) async {
        do {
            let value = try await operation()
            try await writePayload(value, to: path)
            manifest.records.append(FixtureCaptureRecord(name: path, status: .success, message: nil))
        } catch {
            manifest.records.append(FixtureCaptureRecord(
                name: path,
                status: .failure,
                message: error.localizedDescription
            ))
        }
    }

    private func writePayload<T: Encodable>(_ value: T, to path: String) async throws {
        let data = try FixtureLoader.encode(value)
        guard let root = snapshotRoot else { return }
        let assetsDirectory = root.appendingPathComponent("assets", isDirectory: true)
        let rewritten = await assetRewriter.rewriteAssets(in: data, assetsDirectory: assetsDirectory)
        manifest.assets.append(contentsOf: rewritten.assets)
        rewritten.failures.forEach {
            manifest.records.append(FixtureCaptureRecord(name: "asset:\(path)", status: .failure, message: $0))
        }
        try writeData(rewritten.data, to: path)
    }

    private func writeRawPayload<T: Encodable>(_ value: T, to path: String) async throws {
        try writeData(FixtureLoader.encoder.encode(value), to: path)
    }

    private func writeData(_ data: Data, to path: String) throws {
        guard let root = snapshotRoot else { return }
        let target = root.appendingPathComponent(path).appendingPathExtension("json")
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: [.atomic])
    }

    private func collectStoreIDs(from stores: [StoreSummary]) {
        storeIDs.formUnion(stores.map(\.store_id))
    }

    private func collectStoreIDs(from orders: [Order]) {
        storeIDs.formUnion(orders.compactMap(\.store.id))
    }

    private func collectStoreIDs(from posts: [PostSummary]) {
        storeIDs.formUnion(posts.compactMap { $0.store?.id })
    }

    private func collectPostIDs(from posts: [PostSummary]) {
        postIDs.formUnion(posts.map(\.post_id))
    }

    private func safeName(_ value: String) -> String {
        let sanitized = value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return sanitized.isEmpty ? "item" : sanitized
    }
}
