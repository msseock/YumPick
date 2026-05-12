import Foundation

enum FixtureFileResolver {
    static let scheme = "fixture"
    static let assetsHost = "assets"

    static var usesFixtures: Bool {
        ProcessInfo.processInfo.arguments.contains("-useFixtures")
    }

    static func fixtureAssetPath(fileName: String) -> String {
        "\(scheme)://\(assetsHost)/\(fileName)"
    }

    static func localAssetURL(from path: String) -> URL? {
        guard
            let url = URL(string: path),
            url.scheme == scheme,
            url.host == assetsHost
        else {
            return nil
        }

        let fileName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !fileName.isEmpty else { return nil }

        return Bundle.main.url(
            forResource: fileName,
            withExtension: nil,
            subdirectory: "Fixtures/assets"
        )
    }

    static func remoteURL(from path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fixtureURL = localAssetURL(from: trimmed) {
            return fixtureURL
        }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        let base = SecretConstants.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalized = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        let apiPath = normalized.hasPrefix("/data/") ? "/v1\(normalized)" : normalized
        return URL(string: base + apiPath)
    }

    static func authenticatedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        guard !url.isFileURL else { return request }

        request.setValue(SecretConstants.sesacKey, forHTTPHeaderField: "SeSACKey")
        if let token = KeychainManager.shared.read(key: .accessToken) {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    static func dataURL(for path: String) -> URL? {
        Bundle.main.url(
            forResource: path,
            withExtension: "json",
            subdirectory: "Fixtures/data"
        )
    }
}
