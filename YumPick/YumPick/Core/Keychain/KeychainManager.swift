import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    enum Key: String {
        case accessToken  = "com.yumpick.accessToken"
        case refreshToken = "com.yumpick.refreshToken"
        case userID       = "com.yumpick.userID"
        case nick         = "com.yumpick.nick"
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
        
        #if DEBUG
        if status == errSecSuccess {
            print("🔐 [KEYCHAIN] Saved: \(key.rawValue)")
        } else {
            print("❌ [KEYCHAIN] Save Failed (\(status)): \(key.rawValue)")
        }
        #endif
    }

    func read(key: Key) -> String? {
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
            return nil
        }
        
        #if DEBUG
        print("🔑 [KEYCHAIN] Read Success: \(key.rawValue)")
        #endif
        return String(data: data, encoding: .utf8)
    }

    func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        
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
    }
}
