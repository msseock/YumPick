import Foundation

final class FixtureAssetRewriter {
    private let session: URLSession
    private let fileManager: FileManager
    private var rewrittenPaths: [String: String] = [:]
    private var usedFileNames = Set<String>()

    private let assetExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "gif", "heic",
        "pdf", "mp4", "mov", "m4v"
    ]

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func rewriteAssets(
        in data: Data,
        assetsDirectory: URL
    ) async -> (data: Data, assets: [FixtureAssetRecord], failures: [String]) {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return (data, [], [])
        }

        var assets: [FixtureAssetRecord] = []
        var failures: [String] = []
        let rewritten = await rewriteJSONObject(
            object,
            key: nil,
            assetsDirectory: assetsDirectory,
            assets: &assets,
            failures: &failures
        )

        guard
            JSONSerialization.isValidJSONObject(rewritten),
            let rewrittenData = try? JSONSerialization.data(withJSONObject: rewritten, options: [.prettyPrinted, .sortedKeys])
        else {
            return (data, assets, failures)
        }

        return (rewrittenData, assets, failures)
    }

    private func rewriteJSONObject(
        _ object: Any,
        key: String?,
        assetsDirectory: URL,
        assets: inout [FixtureAssetRecord],
        failures: inout [String]
    ) async -> Any {
        if let dict = object as? [String: Any] {
            var next: [String: Any] = [:]
            for (key, value) in dict {
                next[key] = await rewriteJSONObject(
                    value,
                    key: key,
                    assetsDirectory: assetsDirectory,
                    assets: &assets,
                    failures: &failures
                )
            }
            return next
        }

        if let array = object as? [Any] {
            var next: [Any] = []
            for value in array {
                next.append(await rewriteJSONObject(
                    value,
                    key: key,
                    assetsDirectory: assetsDirectory,
                    assets: &assets,
                    failures: &failures
                ))
            }
            return next
        }

        guard let value = object as? String, shouldDownload(value, key: key) else {
            return object
        }

        if let cached = rewrittenPaths[value] {
            return cached
        }

        do {
            let record = try await downloadAsset(from: value, to: assetsDirectory)
            rewrittenPaths[value] = record.localPath
            assets.append(record)
            return record.localPath
        } catch {
            failures.append("\(value): \(error.localizedDescription)")
            return object
        }
    }

    private func shouldDownload(_ value: String, key: String?) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, FixtureFileResolver.localAssetURL(from: trimmed) == nil else {
            return false
        }

        let loweredKey = key?.lowercased() ?? ""
        let likelyMediaKey = loweredKey.contains("image")
            || loweredKey.contains("thumbnail")
            || loweredKey.contains("profileimage")
            || loweredKey == "files"
            || loweredKey == "file"

        let ext = pathExtension(from: trimmed)
        guard assetExtensions.contains(ext) else {
            return false
        }

        return likelyMediaKey || trimmed.hasPrefix("/data/") || URL(string: trimmed)?.scheme != nil
    }

    private func downloadAsset(from path: String, to directory: URL) async throws -> FixtureAssetRecord {
        guard let url = FixtureFileResolver.remoteURL(from: path) else {
            throw FixtureDownloadError.invalidURL
        }

        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let request = FixtureFileResolver.authenticatedRequest(for: url)
            let (downloaded, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw FixtureDownloadError.badStatus(http.statusCode)
            }
            data = downloaded
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = uniqueFileName(for: path)
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: [.atomic])

        return FixtureAssetRecord(
            originalPath: path,
            localPath: FixtureFileResolver.fixtureAssetPath(fileName: fileName),
            byteCount: data.count
        )
    }

    private func uniqueFileName(for path: String) -> String {
        let url = URL(string: path)
        let last = url?.lastPathComponent.nilIfBlank ?? (path as NSString).lastPathComponent.nilIfBlank ?? "asset"
        let ext = pathExtension(from: path)
        let base = ((last as NSString).deletingPathExtension.nilIfBlank ?? "asset")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        let normalizedBase = base.isEmpty ? "asset" : base
        var candidate = "\(normalizedBase).\(ext.isEmpty ? "bin" : ext)"
        var counter = 2
        while usedFileNames.contains(candidate) {
            candidate = "\(normalizedBase)-\(counter).\(ext.isEmpty ? "bin" : ext)"
            counter += 1
        }
        usedFileNames.insert(candidate)
        return candidate
    }

    private func pathExtension(from path: String) -> String {
        let parsed = URL(string: path)
        let source = parsed?.path.isEmpty == false ? parsed?.path ?? path : path
        return (source as NSString).pathExtension.lowercased()
    }
}

private enum FixtureDownloadError: LocalizedError {
    case invalidURL
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "유효하지 않은 미디어 URL입니다."
        case .badStatus(let status):
            return "미디어 다운로드 HTTP 상태 코드 \(status)"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
