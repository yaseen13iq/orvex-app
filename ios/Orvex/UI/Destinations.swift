import SwiftUI

/// صفحة تحرير عامة لأي جزء من إعدادات الموقع
struct EditRoute: Hashable { var path: [Seg]; var title: String }
struct UserRoute: Hashable { var id: String }
struct MonitorRoute: Hashable { var id: String; var name: String }
struct CastRoute: Hashable { var id: String }
struct VersionRoute: Hashable { var id: Int }

struct DestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: String.self) { Screen(id: $0) }
            .navigationDestination(for: EditRoute.self) { r in ConfigPage(path: r.path, title: r.title) }
            .navigationDestination(for: UserRoute.self) { r in UserEditView(id: r.id) }
            .navigationDestination(for: MonitorRoute.self) { r in MonitorUserView(id: r.id, name: r.name) }
            .navigationDestination(for: CastRoute.self) { r in CastDetailView(id: r.id) }
            .navigationDestination(for: VersionRoute.self) { r in VersionDetailView(id: r.id) }
    }
}
extension View { func withDestinations() -> some View { modifier(DestinationsModifier()) } }

/// كل الصفحات بالاسم
struct Screen: View {
    let id: String
    var body: some View {
        switch id {
        case "gate": GateView()
        case "mode": ModeView()
        case "plans": PlansView()
        case "content": ContentView2()
        case "texts": TextsView()
        case "mood": MoodView()
        case "train": ConfigPage(path: P("train"), title: "وضع التدريب")
        case "look": LookView()
        case "advanced": AdvancedView()
        case "geo": GeoView()
        case "live": LiveView()
        case "speed": SpeedView()
        case "waitlist": WaitlistView()
        case "cast": CastComposeView()
        case "botmsgs": BotMessagesView()
        case "inbox": InboxView()
        case "notify-send": SendNoteView()
        case "files": FilesView()
        case "users": UsersView()
        case "monitor": MonitorView()
        case "history": HistoryView()
        case "log": ActivityLogView()
        case "app-updates": AppUpdatesView()
        case "app-control": AppControlView()
        case "widgets": WidgetsCustomizeView()
        case "settings": SettingsView()
        case "system": SystemView()
        case "account": AccountView()
        case "about": AboutView()
        case "telegram": TelegramView()
        case "update": AppUpdatesView()
        default: EmptyState(icon: "questionmark.circle", text: "الصفحة غير موجودة")
        }
    }
}
