import Foundation
import RealmSwift

enum RealmConfig {
    static let currentSchemaVersion: UInt64 = 3

    static func make() -> Realm.Configuration {
        var config = Realm.Configuration.defaultConfiguration
        config.schemaVersion = currentSchemaVersion
        config.encryptionKey = encryptionKey()
        config.migrationBlock = { _, oldVersion in
            _ = oldVersion
        }
        return config
    }

    private static func encryptionKey() -> Data {
        let keychainKey: KeychainManager.Key = .realmKey
        if let existing = KeychainManager.shared.readData(key: keychainKey),
           existing.count == 64 {
            return existing
        }
        var bytes = Data(count: 64)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 64, $0.baseAddress!) }
        KeychainManager.shared.saveData(bytes, key: keychainKey)
        return bytes
    }
}
