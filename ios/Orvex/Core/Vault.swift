import Foundation
import Security

/// تخزين آمن لرمز الدخول. يستخدم سلسلة المفاتيح (Keychain)، ومخزنًا احتياطيًا إذا لم تكن متاحة مع الشهادة.
enum Vault {
    private static let service = "com.orvex.admin"

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var res: AnyObject?
        if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess, let d = res as? Data, let s = String(data: d, encoding: .utf8) { return s }
        return UserDefaults.standard.string(forKey: "vault." + key)
    }

    @discardableResult
    static func set(_ key: String, _ value: String?) -> Bool {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        let d = UserDefaults.standard
        guard let v = value else { d.removeObject(forKey: "vault." + key); return true }
        var add = base
        add[kSecValueData as String] = Data(v.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(add as CFDictionary, nil) == errSecSuccess { d.removeObject(forKey: "vault." + key); return true }
        d.set(v, forKey: "vault." + key)
        return true
    }
}
