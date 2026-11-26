import SwiftUI
import WidgetKit

@main
struct OrvexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var session = Session.shared
    @StateObject var prefs = Prefs.shared
    @StateObject var guardian = Guardian.shared
    @Environment(\.scenePhase) var phase

    init() {
        BackgroundRefresh.register()
        API.shared.confirmProvider = { hasPin in await Guardian.shared.confirm(hasPin: hasPin) }
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            UserDefaults.standard.removeObject(forKey: "orvex.prefs")
            API.shared.token = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_IQ"))
                .environmentObject(session)
                .environmentObject(prefs)
                .preferredColorScheme(prefs.colorScheme)
                .tint(prefs.theme.accent)
                .task { await session.start() }
                .onOpenURL { url in DeepLink.handle(url) }
        }
        .onChange(of: phase) { _, p in
            switch p {
            case .background:
                guardian.didBackground()
                BackgroundRefresh.schedule()
                WidgetCenter.shared.reloadAllTimelines()
            case .active:
                if guardian.shouldLock() { guardian.locked = true }
                if session.phase == .ready { Task { await session.refreshStatus(); await session.ping() } }
            default: break
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let f = UIFont(name: "ReadexPro-Bold", size: 34) ?? .boldSystemFont(ofSize: 34)
        let f2 = UIFont(name: "ReadexPro-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: f]
        UINavigationBar.appearance().titleTextAttributes = [.font: f2]
        UISegmentedControl.appearance().setTitleTextAttributes([.font: UIFont(name: "ReadexPro-Medium", size: 13) ?? .systemFont(ofSize: 13)], for: .normal)
        return true
    }
}

/// روابط داخلية orvex://… (من الويدجت والجزيرة)
enum DeepLink {
    static func handle(_ url: URL) {
        guard url.scheme == "orvex" else { return }
        let host = url.host ?? ""
        Task { @MainActor in Router.shared.open(host) }
    }
}

/// التنقل العام بين التبويبات والصفحات
@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var tab = Prefs.shared.d.startTab
    @Published var morePath = NavigationPath()
    @Published var sitePath = NavigationPath()
    @Published var statsPath = NavigationPath()
    @Published var tgPath = NavigationPath()
    @Published var homePath = NavigationPath()
    func open(_ dest: String) {
        switch dest {
        case "home", "": tab = "home"
        case "site", "gate", "mode", "plans", "content", "texts", "mood", "train", "look", "geo", "advanced":
            tab = "site"; sitePath = NavigationPath(); if dest != "site" { sitePath.append(dest) }
        case "stats", "live", "speed": tab = "stats"; statsPath = NavigationPath(); if dest != "stats" { statsPath.append(dest) }
        case "telegram", "waitlist", "cast", "botmsgs": tab = "telegram"; tgPath = NavigationPath(); if dest != "telegram" { tgPath.append(dest) }
        case "search": tab = "search"
        case "update": if let u = Session.shared.app["update"].object { Session.shared.pendingUpdate = .object(u) }
        default: tab = "more"; morePath = NavigationPath(); morePath.append(dest)
        }
    }
}
