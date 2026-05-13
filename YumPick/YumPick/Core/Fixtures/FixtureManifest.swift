import Foundation

struct FixtureManifest: Codable {
    let generatedAt: String
    let appVersion: String
    var records: [FixtureCaptureRecord]
    var assets: [FixtureAssetRecord]

    static func make() -> FixtureManifest {
        FixtureManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            records: [],
            assets: []
        )
    }
}

struct FixtureCaptureRecord: Codable {
    enum Status: String, Codable {
        case success
        case failure
    }

    let name: String
    let status: Status
    let message: String?
}

struct FixtureAssetRecord: Codable, Hashable {
    let originalPath: String
    let localPath: String
    let byteCount: Int
}
