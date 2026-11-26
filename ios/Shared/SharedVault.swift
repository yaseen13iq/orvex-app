import Foundation
import Security

/// تخزين آمن بالـKeychain، مع مجموعة مشتركة بين التطبيق والويدجت.
/// شهادات مواقع التوقيع غالبًا ما تدعم App Groups، فنكتشف بادئة الفريق وقت التشغيل
/// ونستخدم مجموعة Keychain مشتركة. إذا ما نجحت، نرجع للتخزين العادي.
public enum Vault {
    public static let service = "com.orvex.admin"
    private static var cachedPrefix: String?

    /// بادئة الفريق (Team ID) من مجموعة الوصول الافتراضية
    public static var teamPrefix: String? {
        if let p = cachedPrefix { return p }
        let probe = "orvex.prefix.probe"
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service + ".probe", kSecAttrAccount as String: probe, kSecReturnAttributes as String: true]
        var res: AnyObject?
        var st = SecItemCopyMatching(q as CFDictionary, &res)
        if st == errSecItemNotFound {
            let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service + ".probe", kSecAttrAccount as String: probe, kSecValueData as String: Data("1".utf8), kSecReturnAttributes as String: true, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
            st = SecItemAdd(add as CFDictionary, &res)
        }
        guard st == errSecSuccess, let attrs = res as? [String: Any], let group = attrs[kSecAttrAccessGroup as String] as? String else { return nil }
        let prefix = group.components(separatedBy: ".").first
        cachedPrefix = prefix
        return prefix
    }
    public static var sharedGroup: String? { teamPrefix.map { "\($0).com.orvex.shared" } }

    private static func base(_ key: String, group: String?) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        if let g = group { q[kSecAttrAccessGroup as String] = g }
        return q
    }
    @discardableResult
    public static func set(_ key: String, _ value: String?, shared: Bool = false) -> Bool {
        let groups: [String?] = shared ? [sharedGroup, nil] : [nil]
        var ok = false
        for g in groups {
            let q = base(key, group: g)
            SecItemDelete(q as CFDictionary)
            guard let v = value else { ok = true; continue }
            var add = q
            add[kSecValueData as String] = Data(v.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            if SecItemAdd(add as CFDictionary, nil) == errSecSuccess { ok = true; if shared && g != nil { break } }
        }
        // احتياط: إذا الـKeychain مو متاح (بعض الشهادات/المحاكي) نحفظ محليًا حتى ما يطلع المستخدم كل مرة
        let d = UserDefaults.standard
        if value == nil { d.removeObject(forKey: "vault." + key) }
        else if !ok { d.set(value, forKey: "vault." + key); ok = true }
        else { d.removeObject(forKey: "vault." + key) }
        return ok
    }
    public static func get(_ key: String, shared: Bool = false) -> String? {
        let groups: [String?] = shared ? [sharedGroup, nil] : [nil]
        for g in groups {
            var q = base(key, group: g)
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var res: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess, let d = res as? Data, let s = String(data: d, encoding: .utf8) { return s }
        }
        return UserDefaults.standard.string(forKey: "vault." + key)
    }
    /// هل الويدجت يكدر يقرأ؟ (للعرض بإعدادات التطبيق)
    public static var sharingWorks: Bool {
        guard let g = sharedGroup else { return false }
        let k = "orvex.share.test"
        let q = base(k, group: g)
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data("1".utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}

/// بيانات مشتركة للويدجت والجزيرة
public enum SharedKeys {
    public static let token = "token"
    public static let base = "base"
    public static let widgetPrefs = "widgetPrefs"
    public static let lastStatus = "lastStatus"
}

public struct WidgetPrefs: Codable, Equatable {
    public var theme: String = "auto"          // auto | light | dark
    public var hideSensitive: Bool = false
    public var showLive: Bool = true
    public var showVisits: Bool = true
    public var showWaitlist: Bool = true
    public var showGate: Bool = true
    public var showVersion: Bool = false
    public var islandEnabled: Bool = false
    public var islandStatus: Bool = true
    public var islandMaintenance: Bool = true
    public var islandSchedule: Bool = true
    public var islandCast: Bool = true
    public var islandAlerts: Bool = true
    public var islandProblems: Bool = true
    public init() {}
    public static func load() -> WidgetPrefs {
        guard let s = Vault.get(SharedKeys.widgetPrefs, shared: true), let d = s.data(using: .utf8), let p = try? JSONDecoder().decode(WidgetPrefs.self, from: d) else { return WidgetPrefs() }
        return p
    }
    public func save() {
        if let d = try? JSONEncoder().encode(self), let s = String(data: d, encoding: .utf8) { Vault.set(SharedKeys.widgetPrefs, s, shared: true) }
    }
}

/// استدعاء خفيف للحالة (يستخدمه الويدجت)
public enum StatusFetcher {
    public static func fetch() async -> JSON? {
        guard let token = Vault.get(SharedKeys.token, shared: true), let base = Vault.get(SharedKeys.base, shared: true), let url = URL(string: base + "/admin/api/status") else {
            return cached()
        }
        var r = URLRequest(url: url, timeoutInterval: 12)
        r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200, let j = try? JSONCodec.parse(d) else { return cached() }
        Vault.set(SharedKeys.lastStatus, String(decoding: d, as: UTF8.self), shared: true)
        return j
    }
    public static func cached() -> JSON? {
        guard let s = Vault.get(SharedKeys.lastStatus, shared: true) else { return nil }
        return try? JSONCodec.parse(s)
    }
}
