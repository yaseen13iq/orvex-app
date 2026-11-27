import SwiftUI

@main
struct OrvexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var session = Session.shared
    @StateObject var prefs = Prefs.shared
    @Environment(\.scenePhase) var phase

    init() {
        API.shared.confirmProvider = { _ in await Confirmer.shared.ask() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_IQ"))
                .environmentObject(session)
                .environmentObject(prefs)
                .preferredColorScheme(prefs.colorScheme)
                .tint(C.info)
                .task { await session.start() }
                .onOpenURL { url in if let h = url.host { Router.shared.open(h) } }
        }
        .onChange(of: phase) { _, p in
            if p == .active, session.phase == .ready { Task { await session.refreshStatus(); await ConfigStore.shared.load() } }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let big = UIFont(name: "ReadexPro-Bold", size: 32) ?? .boldSystemFont(ofSize: 32)
        let small = UIFont(name: "ReadexPro-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let nav = UINavigationBar.appearance()
        nav.largeTitleTextAttributes = [.font: big]
        nav.titleTextAttributes = [.font: small]
        let tab = UITabBarItem.appearance()
        let tf = UIFont(name: "ReadexPro-Medium", size: 10.5) ?? .systemFont(ofSize: 10.5)
        tab.setTitleTextAttributes([.font: tf], for: .normal)
        tab.setTitleTextAttributes([.font: tf], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont(name: "ReadexPro-Medium", size: 13) ?? .systemFont(ofSize: 13)], for: .normal)
        return true
    }
}

/// التنقّل بين التبويبات والصفحات
@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var tab = "home"
    @Published var homePath = NavigationPath()
    @Published var sitePath = NavigationPath()
    @Published var statsPath = NavigationPath()
    @Published var adminPath = NavigationPath()

    static let siteScreens: Set<String> = ["gate", "schedule", "plans", "pricing", "content", "sections", "faq", "pages", "links", "mode", "geo", "look", "mood", "texts", "seo"]
    static let statsScreens: Set<String> = ["live", "speed"]

    /// يفتح صفحة بالاسم (يستخدم للروابط والاختبارات)
    func open(_ dest: String) {
        if dest == "home" { tab = "home"; homePath = NavigationPath(); return }
        if dest == "site" { tab = "site"; sitePath = NavigationPath(); return }
        if dest == "stats" { tab = "stats"; statsPath = NavigationPath(); return }
        if dest == "admin" { tab = "admin"; adminPath = NavigationPath(); return }
        if dest == "update" { if let u = Session.shared.app["update"].object { Session.shared.pendingUpdate = .object(u) }; return }
        if dest.hasPrefix("form:"), let id = dest.split(separator: ":").last {
            tab = "site"; sitePath = NavigationPath(); sitePath.append(AnyHashableRoute.form(String(id), formBase(String(id)))); return
        }
        if dest.hasPrefix("list:"), let id = dest.split(separator: ":").last {
            tab = "site"; sitePath = NavigationPath(); sitePath.append(AnyHashableRoute.list(String(id), listBase(String(id)))); return
        }
        if Router.siteScreens.contains(dest) { tab = "site"; sitePath = NavigationPath(); sitePath.append(dest); return }
        if Router.statsScreens.contains(dest) { tab = "stats"; statsPath = NavigationPath(); statsPath.append(dest); return }
        tab = "admin"; adminPath = NavigationPath(); adminPath.append(dest)
    }
    func formBase(_ id: String) -> [Seg] {
        switch id {
        case "gate-extra": return P("gate")
        case "vip", "included", "goals", "steps", "compare", "gym", "train", "changelog", "gallery", "developer", "visitors", "maintenance", "offline": return P(id)
        case "bot": return P("notify")
        case "page-about": return P("pages", "about")
        case "page-terms": return P("pages", "terms")
        case "page-privacy": return P("pages", "privacy")
        default: return []
        }
    }
    func listBase(_ id: String) -> [Seg] {
        switch id { case "plans": return P("plans"); case "counters": return P("counters"); case "faq": return P("faq"); default: return [] }
    }
}
