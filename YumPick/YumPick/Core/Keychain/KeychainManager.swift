import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    private var cachedValues: [Key: String] = [:]
    private var cachedEmptyKeys: Set<Key> = []

    enum Key: String {
        case accessToken  = "com.yumpick.accessToken"
        case refreshToken = "com.yumpick.refreshToken"
        case userID       = "com.yumpick.userID"
        case nick         = "com.yumpick.nick"
        case loginProvider = "com.yumpick.loginProvider"
        case appleUserID  = "com.yumpick.appleUserID"
        case logoutRequired = "com.yumpick.logoutRequired"
        case fcmToken     = "com.yumpick.fcmToken"
        case realmKey     = "com.yumpick.realmKey"
    }

    func save(key: Key, value: String) {
        let data = Data(value.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        cachedValues[key] = value
        cachedEmptyKeys.remove(key)
        
        #if DEBUG
        if status == errSecSuccess {
            print("🔐 [KEYCHAIN] Saved: \(key.rawValue)")
        } else {
            print("❌ [KEYCHAIN] Save Failed (\(status)): \(key.rawValue)")
        }
        #endif
    }

    func read(key: Key) -> String? {
        if let cachedValue = cachedValues[key] {
            return cachedValue
        }
        if cachedEmptyKeys.contains(key) {
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            #if DEBUG
            print("🔑 [KEYCHAIN] Read Failed or Empty: \(key.rawValue)")
            #endif
            cachedEmptyKeys.insert(key)
            return nil
        }
        
        #if DEBUG
        print("🔑 [KEYCHAIN] Read Success: \(key.rawValue)")
        #endif
        let value = String(data: data, encoding: .utf8)
        if let value {
            cachedValues[key] = value
            cachedEmptyKeys.remove(key)
        } else {
            cachedEmptyKeys.insert(key)
        }
        return value
    }

    func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        cachedValues.removeValue(forKey: key)
        cachedEmptyKeys.insert(key)
        
        #if DEBUG
        if status == errSecSuccess {
            print("🗑️ [KEYCHAIN] Deleted: \(key.rawValue)")
        } else if status != errSecItemNotFound {
            print("❌ [KEYCHAIN] Delete Failed (\(status)): \(key.rawValue)")
        }
        #endif
    }

    func deleteAll() {
        #if DEBUG
        print("🧹 [KEYCHAIN] Deleting All Keys...")
        #endif
        delete(key: .accessToken)
        delete(key: .refreshToken)
        delete(key: .userID)
        delete(key: .nick)
        delete(key: .loginProvider)
        delete(key: .appleUserID)
        delete(key: .logoutRequired)
        delete(key: .fcmToken)
    }

    func saveData(_ data: Data, key: Key) {
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        #if DEBUG
        if status == errSecSuccess {
            print("🔐 [KEYCHAIN] Data Saved: \(key.rawValue)")
        } else {
            print("❌ [KEYCHAIN] Data Save Failed (\(status)): \(key.rawValue)")
        }
        #endif
    }

    func readData(key: Key) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }
}
