import Foundation
import ZIPFoundation

enum FixtureRuntimeStore {
    private static let fileManager = FileManager.default
    private static let legacyDataDirectories = [
        "home",
        "pick",
        "order",
        "community",
        "profile",
        "chat",
        "store",
        "review",
        "video"
    ]

    static var rootDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Fixtures", isDirectory: true)
    }

    static var activeDirectory: URL {
        rootDirectory.appendingPathComponent("active", isDirectory: true)
    }

    static var hasActiveFixture: Bool {
        containsJSON(in: activeDirectory.appendingPathComponent("data", isDirectory: true))
            || containsLegacyTopLevelData(in: activeDirectory)
    }

    static func importArchive(from sourceURL: URL) throws {
        let securityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let staging = rootDirectory.appendingPathComponent("staging", isDirectory: true)
        if fileManager.fileExists(atPath: staging.path) {
            try fileManager.removeItem(at: staging)
        }
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: sourceURL, to: staging)

        let resolvedRoot = try normalizedFixtureRoot(from: staging)
        try normalizeLegacyTopLevelDataIfNeeded(in: resolvedRoot)
        guard containsJSON(in: resolvedRoot.appendingPathComponent("data", isDirectory: true)) else {
            throw FixtureImportError.missingDataDirectory
        }

        if fileManager.fileExists(atPath: activeDirectory.path) {
            try fileManager.removeItem(at: activeDirectory)
        }
        try fileManager.moveItem(at: resolvedRoot, to: activeDirectory)
        if fileManager.fileExists(atPath: staging.path) {
            try? fileManager.removeItem(at: staging)
        }
    }

    static func clearActiveFixture() throws {
        if fileManager.fileExists(atPath: activeDirectory.path) {
            try fileManager.removeItem(at: activeDirectory)
        }
    }

    static func dataURL(for path: String) -> URL? {
        let url = activeDirectory
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent(path)
            .appendingPathExtension("json")
        if fileManager.fileExists(atPath: url.path) {
            return url
        }

        let legacyURL = activeDirectory
            .appendingPathComponent(path)
            .appendingPathExtension("json")
        return fileManager.fileExists(atPath: legacyURL.path) ? legacyURL : nil
    }

    static func dataURLs(in directory: String) -> [URL] {
        let url = activeDirectory
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent(directory, isDirectory: true)
        let urls = jsonURLs(in: url)
        if !urls.isEmpty {
            return urls
        }

        return jsonURLs(in: activeDirectory.appendingPathComponent(directory, isDirectory: true))
    }

    static func assetURL(fileName: String) -> URL? {
        let url = activeDirectory
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private static func normalizedFixtureRoot(from staging: URL) throws -> URL {
        let directData = staging.appendingPathComponent("data")
        if fileManager.fileExists(atPath: directData.path) {
            return staging
        }

        let children = try fileManager.contentsOfDirectory(
            at: staging,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        if let nested = children.first(where: { child in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return false
            }
            return fileManager.fileExists(atPath: child.appendingPathComponent("data").path)
        }) {
            return nested
        }

        return staging
    }

    private static func normalizeLegacyTopLevelDataIfNeeded(in root: URL) throws {
        let dataDirectory = root.appendingPathComponent("data", isDirectory: true)
        if containsJSON(in: dataDirectory) {
            return
        }

        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        for directoryName in legacyDataDirectories {
            let legacyDirectory = root.appendingPathComponent(directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: legacyDirectory.path) else { continue }

            let target = dataDirectory.appendingPathComponent(directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.moveItem(at: legacyDirectory, to: target)
        }
    }

    private static func containsLegacyTopLevelData(in root: URL) -> Bool {
        legacyDataDirectories.contains { directoryName in
            containsJSON(in: root.appendingPathComponent(directoryName, isDirectory: true))
        }
    }

    private static func containsJSON(in directory: URL) -> Bool {
        !jsonURLs(in: directory).isEmpty
    }

    private static func jsonURLs(in directory: URL) -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "json" else { return nil }
            return url
        }
    }
}

enum FixtureImportError: LocalizedError {
    case missingDataDirectory

    var errorDescription: String? {
        switch self {
        case .missingDataDirectory:
            return "ZIP 안에서 data 폴더를 찾을 수 없습니다."
        }
    }
}
