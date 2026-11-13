import Foundation
import Security

/// Lưu chuỗi bí mật (token API) trong Keychain — không dùng UserDefaults.
enum Keychain {
    private static let service = "com.tiranix.tiramissu"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Ghi (hoặc xoá nếu `value` rỗng). Trả `false` nếu Keychain từ chối.
    @discardableResult
    static func write(_ account: String, _ value: String?) -> Bool {
        SecItemDelete(query(account) as CFDictionary)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return true }
        var q = query(account)
        q[kSecValueData as String] = data
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }
}
