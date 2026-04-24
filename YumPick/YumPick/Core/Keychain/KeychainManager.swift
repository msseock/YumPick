import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    enum Key: String {
        case accessToken  = "com.yumpick.accessToken"
        case refreshToken = "com.yumpick.refreshToken"
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
        SecItemAdd(addQuery as CFDictionary, nil)
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
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: Key) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    func deleteAll() {
        delete(key: .accessToken)
        delete(key: .refreshToken)
    }
}
