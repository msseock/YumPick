import Foundation
import ZIPFoundation

struct FixtureArchiveExporter {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeSnapshotRoot() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "yumpick-fixtures-\(formatter.string(from: Date()))"
        let root = fileManager.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: root.path) {
            try fileManager.removeItem(at: root)
        }
        try fileManager.createDirectory(at: root.appendingPathComponent("data"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: root.appendingPathComponent("assets"), withIntermediateDirectories: true)
        return root
    }

    func zip(snapshotRoot: URL) throws -> URL {
        let destination = snapshotRoot.deletingPathExtension().appendingPathExtension("zip")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.zipItem(at: snapshotRoot, to: destination, shouldKeepParent: false)
        return destination
    }
}
