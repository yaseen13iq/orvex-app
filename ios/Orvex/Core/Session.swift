import SwiftUI
import LocalAuthentication
import WidgetKit

// MARK: - الجلسة
@MainActor
final class Session: ObservableObject {
    static let shared = Session()
    enum Phase: Equatable { case loading, login, ready, killed(String), offline(String) }

    @Published var phase: Phase = .loading
    @Published var me: JSON = .null
    @Published var perms: [JSON] = []
    @Published var app: JSON = .null
    @Published var unread = 0
    @Published var status: JSON = .null
    @Published var page = "home"
    @Published var pendingUpdate: JSON? = nil
    @Published var alert: JSON? = nil
    @Published var lastSync: Date? = nil
    private var pingTask: Task<Void, Never>?
    private var lastAlertId: Int = UserDefaults.standard.integer(forKey: "orvex.lastAlert")

    var isOwner: Bool { me["role"].string == "owner" }
    var name: String { me["name"].string ?? me["username"].string ?? "" }
    func can(_ k: String) -> Bool {
        if isOwner { return true }
        let p = me["perms"]
        if p[k].isTrue { return true }
        if k.hasPrefix("mode.") && p["mode"].isTrue { return true }
        if k == "live" && p["stats"].isTrue { return true }
        return false
    }
    func canAny(_ ks: [String]) -> Bool { ks.contains { can($0) } }

    init() {
        NotificationCenter.default.addObserver(forName: .orvexUnauthorized, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.signOutLocal() }
        }
        NotificationCenter.default.addObserver(forName: .orvexKilled, object: nil, queue: .main) { [weak self] n in
            Task { @MainActor in self?.phase = .killed((n.object as? String) ?? "التطبيق موقوف مؤقتًا") }
        }
    }

    func start() async {
        guard API.shared.token != nil else { phase = .login; return }
        await boot()
    }

    func boot() async {
        do {
            let r = try await API.shared.get("/app/boot")
            me = r["me"]; perms = r["perms"].arr; app = r["app"]; unread = r["unread"].int ?? 0
            Prefs.shared.applyAdmin(app["display"], canCustomize: can("app.customize"))
            if !app["enabled"].isTrue && !isOwner { phase = .killed(app["message"].text.isEmpty ? "التطبيق موقوف مؤقتًا" : app["message"].text); return }
            let up = app["update"]
            if (up["build"].int ?? 0) > Bundle.main.build, Prefs.shared.d.showUpdateCard || up["mandatory"].isTrue { pendingUpdate = up } else { pendingUpdate = nil }
            phase = .ready
            if let r = ProcessInfo.processInfo.environment["ORVEX_ROUTE"], !r.isEmpty { Router.shared.open(r) }
            if ProcessInfo.processInfo.environment["ORVEX_NO_UPDATE"] == "1" { pendingUpdate = nil }
            startPing()
            await refreshStatus()
        } catch let e as APIError {
            if e.status == 401 { signOutLocal() }
            else if e.status == 423 { phase = .killed(e.message) }
            else if e.status == 0 { phase = .offline(e.message) }
            else { phase = .offline(e.message) }
        } catch { phase = .offline(error.localizedDescription) }
    }

    func login(username: String, password: String) async throws {
        let dev = UIDevice.current
        let r = try await API.shared.post("/login", ["username": .string(username), "password": .string(password), "client": "app", "device": .string(dev.name)])
        guard let t = r["token"].string else { throw APIError(status: 0, message: "ما وصل رمز الدخول") }
        API.shared.token = t
        Vault.set("lastUser", username)
        await boot()
    }

    func logout() async {
        _ = try? await API.shared.post("/logout")
        signOutLocal()
    }
    func signOutLocal() {
        pingTask?.cancel(); pingTask = nil
        API.shared.token = nil
        me = .null; status = .null; unread = 0
        LiveCenter.shared.endAll()
        WidgetCenter.shared.reloadAllTimelines()
        phase = .login
    }

    // MARK: نبض الحضور (المراقبة الصامتة) والإشعارات
    func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.ping()
                try? await Task.sleep(nanoseconds: 25_000_000_000)
            }
        }
    }
    func ping() async {
        guard phase == .ready else { return }
        let d = UIDevice.current
        var sysInfo = utsname(); uname(&sysInfo)
        let model = withUnsafePointer(to: &sysInfo.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
        if let r = try? await API.shared.post("/ping", ["page": .string(page), "device": ["model": .string(model), "os": .string(d.systemVersion), "app": .string(Bundle.main.version), "name": .string(d.name)]]) {
            let old = unread
            unread = r["unread"].int ?? 0
            if let a = r["alert"].object, let id = a["id"]?.int, id != lastAlertId {
                lastAlertId = id; UserDefaults.standard.set(id, forKey: "orvex.lastAlert")
                alert = r["alert"]
                LiveCenter.shared.alert(title: r["alert"]["title"].str, detail: r["alert"]["body"].str, level: r["alert"]["level"].str)
            } else if unread > old {
                Prefs.shared.notify(.success)
            }
            lastSync = Date()
        }
    }
    func refreshStatus() async {
        if let s = try? await API.shared.get("/status") {
            status = s
            LiveCenter.shared.sync(with: s)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - التنبيهات المؤقتة
@MainActor
final class Toasts: ObservableObject {
    static let shared = Toasts()
    struct Item: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var kind: String = "ok"
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil
        static func == (a: Item, b: Item) -> Bool { a.id == b.id }
    }
    @Published var items: [Item] = []
    func show(_ text: String, _ kind: String = "ok", action: String? = nil, _ fn: (() -> Void)? = nil) {
        let it = Item(text: text, kind: kind, actionTitle: action, action: fn)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { items.append(it); if items.count > 2 { items.removeFirst() } }
        kind == "bad" ? Prefs.shared.notify(.error) : Prefs.shared.notify(.success)
        Task { try? await Task.sleep(nanoseconds: UInt64(action == nil ? 3.5e9 : 9e9)); withAnimation { self.items.removeAll { $0.id == it.id } } }
    }
    func error(_ e: Error) {
        if e is CancellationError { return }
        if let a = e as? APIError, a.status == 499 { return }
        show((e as? APIError)?.message ?? e.localizedDescription, "bad")
    }
}

// MARK: - الفيس آيدي والقفل والتأكيد
@MainActor
final class Guardian: ObservableObject {
    static let shared = Guardian()
    @Published var locked = false
    @Published var confirmAsk: Bool = false
    @Published var confirmHasPin = false
    private var confirmCont: CheckedContinuation<String?, Never>?
    private var backgroundAt: Date?

    var biometryName: String {
        let c = LAContext(); _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType { case .faceID: return "الفيس آيدي"; case .touchID: return "البصمة"; case .opticID: return "Optic ID"; default: return "رمز الجهاز" }
    }
    var biometryIcon: String {
        let c = LAContext(); _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return c.biometryType == .touchID ? "touchid" : "faceid"
    }
    func authenticate(_ reason: String) async -> Bool {
        let c = LAContext()
        c.localizedFallbackTitle = "رمز الجهاز"
        var err: NSError?
        let policy: LAPolicy = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        return (try? await c.evaluatePolicy(policy, localizedReason: reason)) ?? false
    }
    // القفل
    func didBackground() { backgroundAt = Date() }
    func shouldLock() -> Bool {
        let l = Prefs.shared.d.lock
        guard l != "off", Session.shared.phase == .ready else { return false }
        guard let b = backgroundAt else { return l != "off" }
        let s = Date().timeIntervalSince(b)
        return l == "instant" || (l == "1m" && s > 60) || (l == "5m" && s > 300)
    }
    func unlock() async { if await authenticate("افتح تطبيق أورفيكس") { locked = false } }

    // التأكيد للإجراءات الحساسة: فيس آيدي ← الرمز المحفوظ، وإلا يطلب الرمز يدويًا
    func confirm(hasPin: Bool) async -> String? {
        if let saved = Vault.get("pin"), !saved.isEmpty {
            if await authenticate("تأكيد إجراء حساس") { return saved }
        }
        confirmHasPin = hasPin
        return await withCheckedContinuation { c in confirmCont = c; confirmAsk = true }
    }
    func finishConfirm(_ code: String?) {
        confirmAsk = false
        confirmCont?.resume(returning: code); confirmCont = nil
    }
}
