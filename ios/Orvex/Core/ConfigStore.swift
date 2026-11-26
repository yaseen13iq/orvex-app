import SwiftUI

/// إعدادات الموقع + المسودة + الحفظ والتراجع (نفس منطق لوحة التحكم)
@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()
    @Published var cfg: JSON = .null
    @Published var draft: JSON = .null
    @Published var ui: JSON = .null
    @Published var meta: JSON = .null
    @Published var rev = 0
    @Published private(set) var ops: [String: Op] = [:]
    @Published var loading = false
    @Published var saving = false
    @Published var loadedAt: Date?

    struct Op: Equatable { var path: [Seg]; var value: JSON?; var del: Bool { value == nil } }

    var dirtyCount: Int { ops.count }
    var loaded: Bool { cfg.isObject }

    func load(force: Bool = false) async {
        if loaded && !force, let t = loadedAt, Date().timeIntervalSince(t) < 30 { return }
        loading = true
        defer { loading = false }
        do {
            let r = try await API.shared.get("/config")
            apply(r)
            meta = r["meta"]
            loadedAt = Date()
        } catch { Toasts.shared.error(error) }
    }
    func apply(_ r: JSON) {
        if r["cfg"].isObject { cfg = r["cfg"] }
        if r["ui"].isObject { ui = r["ui"] }
        if let v = r["rev"].int { rev = v }
        rebase()
    }
    func rebase() {
        var d = cfg
        for op in ops.values { d.set(op.path, op.value) }
        draft = d
    }

    // MARK: القراءة والكتابة
    func v(_ p: [Seg]) -> JSON { draft.at(p) }
    func set(_ p: [Seg], _ value: JSON?) {
        draft.set(p, value)
        touch(p)
    }
    func touch(_ p: [Seg]) {
        if let hit = ops.first(where: { !$0.value.del && $0.value.path.count < p.count && Array(p.prefix($0.value.path.count)) == $0.value.path }) {
            ops[hit.key] = Op(path: hit.value.path, value: draft.at(hit.value.path))
            return
        }
        let cur = draft.at(p), orig = cfg.at(p), k = pathKey(p)
        let curMissing = cur.isNull && !existsIn(draft, p)
        if cur == orig && existsIn(draft, p) == existsIn(cfg, p) { ops[k] = nil }
        else if curMissing { ops[k] = Op(path: p, value: nil) }
        else { ops[k] = Op(path: p, value: cur) }
    }
    func structural(_ p: [Seg]) {
        for (k, op) in ops where op.path.count > p.count && Array(op.path.prefix(p.count)) == p { ops[k] = nil }
        touch(p)
    }
    private func existsIn(_ j: JSON, _ p: [Seg]) -> Bool {
        guard let last = p.last else { return true }
        let parent = j.at(Array(p.dropLast()))
        switch last {
        case .key(let k): return parent.object?[k] != nil
        case .index(let i): return i < parent.arr.count
        }
    }
    func isDirty(_ p: [Seg]) -> Bool {
        ops.values.contains { op in
            let a = op.path, n = min(a.count, p.count)
            return Array(a.prefix(n)) == Array(p.prefix(n))
        }
    }
    func discard() { ops = [:]; rebase() }

    // MARK: الحفظ
    @discardableResult
    func save(_ what: String? = nil) async -> Bool {
        guard !ops.isEmpty, !saving else { return false }
        saving = true
        defer { saving = false }
        let list = Array(ops.values)
        let body: JSON = [
            "ops": .array(list.map { op in
                var o: JSON = ["p": .array(op.path.map(\.json))]
                if let v = op.value { o["v"] = v } else { o["del"] = true }
                return o
            }),
            "what": .string(what ?? Labels.describe(list.map(\.path), store: self)),
        ]
        do {
            let r = try await API.shared.post("/config/patch", body)
            ops = [:]
            apply(r)
            let ver = r["version"].int
            Prefs.shared.notify(.success)
            Toasts.shared.show(r["same"].isTrue ? "ماكو تغيير فعلي" : "انحفظ ✓ " + (r["version_name"].string ?? ""), "ok", action: ver != nil && Session.shared.can("history.undo") ? "تراجع" : nil) {
                if let v = ver { Task { await self.undo(v) } }
            }
            Task { await Session.shared.refreshStatus() }
            return true
        } catch {
            if let e = error as? APIError, let first = e.data["errors"].arr.first {
                Toasts.shared.show(e.message + " — " + Labels.pathLabel(pathFromJSON(first["p"]), store: self), "bad")
            } else { Toasts.shared.error(error) }
            return false
        }
    }
    /// حفظ فوري لتعديلات محددة (مثل فتح/سد الاشتراكات من الرئيسية)
    func quick(_ changes: [([Seg], JSON?)], what: String) async {
        for (p, v) in changes { set(p, v) }
        await save(what)
    }
    func undo(_ version: Int, force: Bool = false) async {
        do {
            let r = try await API.shared.post("/history/undo", ["id": .number(Double(version)), "force": .bool(force)])
            apply(r)
            Toasts.shared.show(r["same"].isTrue ? "كل شي راجع أصلًا" : "تم التراجع ✓")
        } catch let e as APIError where e.status == 409 {
            Toasts.shared.show("بعض الإعدادات تغيّرت بعدها — افتح سجل التعديلات للتراجع بالقوة", "warn")
        } catch { Toasts.shared.error(error) }
    }

    // MARK: الصلاحيات حسب المسار (نفس السيرفر)
    func canPath(_ p: [Seg]) -> Bool {
        let s = Session.shared
        if s.isOwner { return true }
        guard let k = p.first?.keyName else { return false }
        if ["admins", "audit", "rev", "updatedAt", "updatedBy", "v", "stats"].contains(k) { return false }
        if k == "mode" || k == "modeBefore" { return s.can("mode.maintenance") || s.can("mode.offline") }
        var need: String
        if k == "gate", let k2 = p.dropFirst().first?.keyName, k2 == "state" || k2 == "text" { need = "gate.state" }
        else if k == "gate", p.dropFirst().first?.keyName == "schedule" { need = "gate.schedule" }
        else if k == "app", p.dropFirst().first?.keyName == "update" { need = "app.updates" }
        else {
            let map = ["gate": "gate", "maintenance": "mode.maintenance", "offline": "mode.offline", "design": "design", "themes": "themes", "geo": "geo", "app": "app.control", "plans": "plans", "vip": "plans", "currency": "plans", "bar": "plans", "texts": "texts", "mood": "mood", "train": "train", "ui": "look", "visitors": "look", "notify": "notify"]
            need = map[k] ?? "content"
        }
        if s.can(need) { return true }
        if s.can("advanced") && !["geo", "app.control", "app.updates", "gate.state", "gate.schedule"].contains(need) { return true }
        let ps = p.map(\.description).joined(separator: ".")
        if s.can("look") && meta["sections"].arr.contains(where: { $0["p"].string == ps }) { return true }
        if s.can("notify") && ps.hasPrefix("gate.remind") { return true }
        return false
    }

    // MARK: Bindings
    func b(_ p: [Seg]) -> Binding<JSON> { Binding(get: { self.v(p) }, set: { self.set(p, $0) }) }
    func text(_ p: [Seg], lang: String? = nil) -> Binding<String> {
        Binding(get: {
            let j = self.v(p)
            if let l = lang { return j[l].string ?? "" }
            return j.string ?? j.str
        }, set: { nv in
            if let l = lang {
                var j = self.v(p); if !j.isObject { j = ["ar": "", "en": ""] }
                j[l] = .string(nv); self.set(p, j)
            } else { self.set(p, .string(nv)) }
        })
    }
    func bool(_ p: [Seg]) -> Binding<Bool> { Binding(get: { self.v(p).isTrue }, set: { self.set(p, .bool($0)) }) }
    func number(_ p: [Seg]) -> Binding<Double> { Binding(get: { self.v(p).double ?? 0 }, set: { self.set(p, .number($0)) }) }
    func date(_ p: [Seg]) -> Binding<Date> {
        Binding(get: { self.v(p).date ?? Date().addingTimeInterval(86400) }, set: { self.set(p, .number(($0.timeIntervalSince1970 * 1000).rounded())) })
    }
    func hidden(_ p: [Seg]) -> Bool { v(P("texts", "hide")).object?[p.map(\.description).joined(separator: ".")]?.isTrue == true }
    func toggleHidden(_ p: [Seg]) {
        let k = p.map(\.description).joined(separator: ".")
        let hp: [Seg] = [.key("texts"), .key("hide"), .key(k)]
        if hidden(p) { set(hp, nil) } else { set(hp, .bool(true)) }
    }
}
