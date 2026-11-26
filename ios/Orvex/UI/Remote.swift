import SwiftUI

/// تحميل بيانات من السيرفر مع تحديث تلقائي اختياري
@MainActor
final class Remote: ObservableObject {
    @Published var data: JSON = .null
    @Published var error: String?
    @Published var loading = false
    var path: String
    private var timer: Task<Void, Never>?
    init(_ path: String) { self.path = path }

    var loaded: Bool { !data.isNull }

    func load(_ newPath: String? = nil) async {
        if let p = newPath { path = p }
        loading = true
        defer { loading = false }
        do { data = try await API.shared.get(path); error = nil }
        catch is CancellationError {}
        catch { self.error = (error as? APIError)?.message ?? error.localizedDescription }
    }
    func every(_ secs: Double) {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(secs * 1e9))
                if Task.isCancelled { break }
                await self?.load()
            }
        }
    }
    func stop() { timer?.cancel(); timer = nil }
}

/// غلاف يعرض التحميل أو الخطأ أو المحتوى
struct RemoteBody<Content: View>: View {
    @ObservedObject var r: Remote
    @ViewBuilder var content: () -> Content
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        if r.loaded { content() }
        else if let e = r.error {
            VStack(spacing: 14) {
                EmptyState(icon: "exclamationmark.triangle", text: "ما انفتحت الصفحة", sub: e)
                AsyncButton(action: { await r.load() }) { Label("جرّب مرة ثانية", systemImage: "arrow.clockwise") }.buttonStyle(.oxGlass)
            }.frame(maxWidth: .infinity).padding(.top, 60)
        } else { Loading().frame(maxWidth: .infinity).padding(.top, 60) }
    }
}

/// شبكة بطاقات KPI متجاوبة
struct KPIGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.horizontalSizeClass) var hs
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: hs == .regular ? 4 : 2), spacing: 10) { content() }
    }
}

/// صف عنوان + قيمة
struct InfoRow: View {
    var title: String
    var value: String
    var icon: String? = nil
    var tone: String? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        HStack(spacing: 10) {
            if let i = icon { Image(systemName: i).foregroundStyle(prefs.theme.mute).frame(width: 22) }
            Text(title).font(.ox(14.5)).foregroundStyle(prefs.theme.ink2)
            Spacer(minLength: 8)
            Text(value).font(.ox(14.5, .medium)).foregroundStyle(toneColor(tone, prefs.theme) ?? prefs.theme.ink).multilineTextAlignment(.trailing).lineLimit(2)
        }
    }
}

/// مشاركة ملف
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
struct ShareItem: Identifiable { let id = UUID(); let url: URL }

extension String {
    /// تحويل HTML تيليجرام لنص عادي للمعاينة
    var tgPlain: String {
        var s = self.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (a, b) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] { s = s.replacingOccurrences(of: a, with: b) }
        return s
    }
    /// HTML تيليجرام ← AttributedString (عريض، مائل، روابط)
    var tgAttributed: AttributedString {
        var out = AttributedString()
        var bold = 0, italic = 0, code = 0
        var link: URL? = nil
        let scanner = self.replacingOccurrences(of: "\r", with: "")
        var i = scanner.startIndex
        var buf = ""
        func flush() {
            guard !buf.isEmpty else { return }
            var a = AttributedString(buf.tgPlain)
            var f = Font.ox(15, bold > 0 ? .bold : .regular)
            if italic > 0 { f = f.italic() }
            if code > 0 { f = .system(size: 14, design: .monospaced) }
            a.font = f
            if let l = link { a.link = l; a.underlineStyle = .single }
            out += a; buf = ""
        }
        while i < scanner.endIndex {
            if scanner[i] == "<", let close = scanner[i...].firstIndex(of: ">") {
                let tag = String(scanner[scanner.index(after: i)..<close]).lowercased()
                flush()
                switch tag {
                case "b", "strong": bold += 1
                case "/b", "/strong": bold = max(0, bold - 1)
                case "i", "em": italic += 1
                case "/i", "/em": italic = max(0, italic - 1)
                case "code", "pre": code += 1
                case "/code", "/pre": code = max(0, code - 1)
                case "/a": link = nil
                default:
                    if tag.hasPrefix("a "), let r = tag.range(of: "href=\"([^\"]+)\"", options: .regularExpression) {
                        let h = String(String(scanner[scanner.index(after: i)..<close])[r]).replacingOccurrences(of: "href=", with: "", options: .caseInsensitive).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        link = URL(string: h.replacingOccurrences(of: "&amp;", with: "&"))
                    } else if tag.hasPrefix("br") { buf += "\n" }
                }
                i = scanner.index(after: close)
            } else { buf.append(scanner[i]); i = scanner.index(after: i) }
        }
        flush()
        return out
    }
}

/// فقاعة رسالة تيليجرام للمعاينة
struct TGBubble: View {
    var html: String
    var plain = false
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                if plain { Text(html).font(.ox(15)) } else { Text(html.tgAttributed) }
                Text(Fmt.time(Date())).font(.num(10, .regular)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(12)
            .foregroundStyle(prefs.theme.dark ? Color.white : Color.black)
            .background(prefs.theme.dark ? Color(hex: 0x182533) : Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous))
            Spacer(minLength: 30)
        }
        .padding(12)
        .background(prefs.theme.dark ? Color(hex: 0x0E1621) : Color(hex: 0xC6DDB8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
