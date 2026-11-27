import SwiftUI

// MARK: - الجلسة
@MainActor
final class Session: ObservableObject {
    static let shared = Session()
    enum Phase: Equatable { case loading, login, ready, killed(String), offline(String) }

    @Published var phase: Phase = .loading
    @Published var me: JSON = .null
    @Published var app: JSON = .null
    @Published var unread = 0
    @Published var status: JSON = .null
    @Published var page = "home"
    @Published var pendingUpdate: JSON? = nil
    @Published var alert: JSON? = nil
    private var pingTask: Task<Void, Never>?
    private var lastAlertId: Int = UserDefaults.standard.integer(forKey: "orvex.lastAlert")

    var isOwner: Bool { me["role"].string == "owner" }
    var name: String { me["name"].string ?? me["username"].string ?? "" }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    /// هل يملك المستخدم هذه الصلاحية؟ (المسؤول الرئيسي يملك كل شيء)
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
            Task { @MainActor in self?.phase = .killed((n.object as? String) ?? "التطبيق متوقف مؤقتًا.") }
        }
    }

    func start() async {
        guard API.shared.token != nil else { phase = .login; return }
        await boot()
    }

    func boot() async {
        do {
            let r = try await API.shared.get("/app/boot")
            me = r["me"]; app = r["app"]; unread = r["unread"].int ?? 0
            Prefs.shared.applyAdmin(app["display"], canCustomize: can("app.customize"))
            if !app["enabled"].isTrue && !isOwner {
                phase = .killed(app["message"].text.isEmpty ? "أوقف المسؤول التطبيق مؤقتًا." : app["message"].text); return
            }
            let up = app["update"]
            pendingUpdate = (up["build"].int ?? 0) > Bundle.main.build ? up : nil
            if ProcessInfo.processInfo.environment["ORVEX_NO_UPDATE"] == "1" { pendingUpdate = nil }
            phase = .ready
            if let r = ProcessInfo.processInfo.environment["ORVEX_ROUTE"], !r.isEmpty { Router.shared.open(r) }
            startPing()
            await refreshStatus()
            Task { await ConfigStore.shared.load() }
        } catch let e as APIError {
            if e.status == 401 { signOutLocal() }
            else if e.status == 423 { phase = .killed(e.message) }
            else { phase = .offline(e.message) }
        } catch { phase = .offline(error.localizedDescription) }
    }

    func login(username: String, password: String) async throws {
        let r = try await API.shared.post("/login", ["username": .string(username), "password": .string(password), "client": "app", "device": .string(UIDevice.current.name)])
        guard let t = r["token"].string else { throw APIError(status: 0, message: "لم يصل رمز الدخول من الخادم.") }
        API.shared.token = t
        UserDefaults.standard.set(username, forKey: "orvex.lastUser")
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
        ConfigStore.shared.reset()
        phase = .login
    }

    // MARK: نبض الحضور (لمعرفة من يستخدم التطبيق الآن) والإشعارات
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
        var sys = utsname(); uname(&sys)
        let model = withUnsafePointer(to: &sys.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
        if let r = try? await API.shared.post("/ping", ["page": .string(page), "device": ["model": .string(model), "os": .string(d.systemVersion), "app": .string(Bundle.main.version), "name": .string(d.name)]]) {
            unread = r["unread"].int ?? 0
            if let a = r["alert"].object, let id = a["id"]?.int, id != lastAlertId {
                lastAlertId = id; UserDefaults.standard.set(id, forKey: "orvex.lastAlert")
                alert = r["alert"]
            }
        }
    }
    func refreshStatus() async {
        if let s = try? await API.shared.get("/status") { status = s; unread = s["unread"].int ?? unread }
    }
}

// MARK: - الرسائل المؤقتة أسفل الشاشة
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
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { items = [it] }
        Haptics.notify(kind == "bad" ? .error : .success)
        Task { try? await Task.sleep(nanoseconds: UInt64(action == nil ? 3.5e9 : 8e9)); withAnimation { self.items.removeAll { $0.id == it.id } } }
    }
    func error(_ e: Error) {
        if e is CancellationError { return }
        if let a = e as? APIError, a.status == 499 { return }
        show((e as? APIError)?.message ?? e.localizedDescription, "bad")
    }
}

// MARK: - تأكيد الإجراءات الحسّاسة بكلمة المرور
@MainActor
final class Confirmer: ObservableObject {
    static let shared = Confirmer()
    @Published var asking = false
    private var cont: CheckedContinuation<String?, Never>?
    func ask() async -> String? {
        await withCheckedContinuation { c in cont = c; asking = true }
    }
    func finish(_ code: String?) {
        asking = false
        cont?.resume(returning: code); cont = nil
    }
}

enum Haptics {
    static func tap() { guard Prefs.useHaptics else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func notify(_ t: UINotificationFeedbackGenerator.FeedbackType) { guard Prefs.useHaptics else { return }; UINotificationFeedbackGenerator().notificationOccurred(t) }
}
