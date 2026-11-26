import Foundation
import ActivityKit
import BackgroundTasks
import WidgetKit

/// إدارة الجزيرة التفاعلية (Live Activities)
@MainActor
final class LiveCenter {
    static let shared = LiveCenter()
    private var acts: [String: Activity<OrvexActivityAttributes>] = [:]

    var available: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    init() {
        for a in Activity<OrvexActivityAttributes>.activities { acts[a.attributes.topic] = a }
    }

    func sync(with s: JSON) {
        let p = WidgetPrefs.load()
        guard p.islandEnabled, available, s.isObject else { endAll(); return }
        var want: [String: OrvexActivityAttributes.ContentState] = [:]
        let probs = s["problems"].arr
        if p.islandProblems, !probs.isEmpty {
            want["problem"] = .init(kind: "alert", title: "توجد مشكلة بالموقع", detail: probs.map { $0["t"].str }.joined(separator: " · "), level: "bad", endsAt: nil, startedAt: probs.first?["at"].date ?? Date(), progress: nil, live: nil)
        }
        if p.islandMaintenance, s["mode"].string == "maintenance" {
            want["maintenance"] = .init(kind: "task", title: "الموقع بوضع الصيانة", detail: s["maintenance"]["eta"].date.map { "متوقع ينتهي " + Fmt.time($0) } ?? "الزوار يشوفون صفحة الصيانة", level: "warn", endsAt: s["maintenance"]["eta"].date, startedAt: s["maintenance"]["since"].date, progress: nil, live: nil)
        } else if p.islandMaintenance, s["mode"].string == "offline" {
            want["maintenance"] = .init(kind: "task", title: "الموقع متوقف", detail: "الزوار يشوفون صفحة الإيقاف", level: "bad", endsAt: nil, startedAt: Date(), progress: nil, live: nil)
        }
        if p.islandSchedule, let next = s["schedule"]["next"].object, let at = next["at"]?.date, at.timeIntervalSinceNow < 48 * 3600 {
            let open = next["kind"]?.string == "open"
            want["schedule"] = .init(kind: "task", title: open ? "تنفتح الاشتراكات" : "تنسد الاشتراكات", detail: Fmt.date(at), level: open ? "ok" : "info", endsAt: at, startedAt: nil, progress: nil, live: nil)
        }
        if p.islandCast, let c = s["cast"].object, let total = c["total"]?.double, total > 0 {
            let done = (c["sent"]?.double ?? 0) + (c["failed"]?.double ?? 0)
            want["cast"] = .init(kind: "task", title: "إرسال التذكير", detail: "وصل \(Fmt.n(c["sent"]?.double)) من \(Fmt.n(total))", level: "info", endsAt: nil, startedAt: c["at"]?.date, progress: done / total, live: nil)
        }
        if p.islandStatus, want.isEmpty {
            let h = s["health"].str
            want["status"] = .init(kind: "status", title: h == "ok" ? "الموقع يعمل" : h == "maintenance" ? "صيانة" : h == "down" ? "متوقف" : "تنبيه", detail: s["gate"]["label"].text, level: h == "ok" ? "ok" : h == "warn" ? "warn" : "bad", endsAt: nil, startedAt: nil, progress: nil, live: s["live"].int)
        }
        for (topic, a) in acts where want[topic] == nil && topic != "alert" { end(topic, a) }
        for (topic, st) in want { upsert(topic, st) }
    }

    func alert(title: String, detail: String, level: String) {
        let p = WidgetPrefs.load()
        guard p.islandEnabled, p.islandAlerts, available else { return }
        upsert("alert", .init(kind: "alert", title: title, detail: detail, level: level, endsAt: nil, startedAt: Date(), progress: nil, live: nil), stale: Date().addingTimeInterval(900))
    }

    private func upsert(_ topic: String, _ st: OrvexActivityAttributes.ContentState, stale: Date? = nil) {
        let content = ActivityContent(state: st, staleDate: stale ?? Date().addingTimeInterval(3600))
        if let a = acts[topic], a.activityState == .active {
            if a.content.state != st { Task { await a.update(content) } }
            return
        }
        do {
            let a = try Activity<OrvexActivityAttributes>.request(attributes: OrvexActivityAttributes(topic: topic), content: content, pushType: nil)
            acts[topic] = a
        } catch { }
    }
    private func end(_ topic: String, _ a: Activity<OrvexActivityAttributes>) {
        acts[topic] = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
    func endAll() {
        for (t, a) in acts { end(t, a) }
        for a in Activity<OrvexActivityAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}

/// التحديث بالخلفية: يجيب الحالة ويحدّث الويدجت والجزيرة
enum BackgroundRefresh {
    static let id = "com.orvex.admin.refresh"
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            schedule()
            let t = Task {
                if let s = await StatusFetcher.fetch() {
                    await MainActor.run { LiveCenter.shared.sync(with: s) }
                    WidgetCenter.shared.reloadAllTimelines()
                }
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { t.cancel() }
        }
    }
    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }
}
