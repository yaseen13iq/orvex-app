import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - رافع الملفات (مشترك مع صفحة التحديثات)
@MainActor
final class Uploader: ObservableObject {
    struct Job: Identifiable { let id = UUID(); var name: String; var size: Int64; var progress: Double = 0; var error: String?; var done = false; var file: JSON = .null }
    @Published var jobs: [Job] = []
    var onDone: ((JSON) -> Void)?

    func upload(url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        await run(name: url.lastPathComponent, size: size, type: type) { offset, len in
            guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? h.close() }
            try? h.seek(toOffset: UInt64(offset))
            return try? h.read(upToCount: len)
        }
    }
    func upload(data: Data, name: String, type: String) async {
        await run(name: name, size: Int64(data.count), type: type) { offset, len in
            let end = min(data.count, offset + len)
            return offset < end ? data.subdata(in: offset..<end) : Data()
        }
    }

    private func run(name: String, size: Int64, type: String, read: @escaping (Int, Int) -> Data?) async {
        let job = Job(name: name, size: size)
        let jid = job.id
        jobs.insert(job, at: 0)
        func update(_ f: (inout Job) -> Void) { if let i = jobs.firstIndex(where: { $0.id == jid }) { f(&jobs[i]) } }
        do {
            guard size > 0 else { throw APIError(status: 0, message: "الملف فاضي") }
            let ini = try await API.shared.post("/files/init", ["name": .string(name), "size": .number(Double(size)), "type": .string(type)])
            let id = ini["id"].str
            var res: JSON
            if ini["mode"].str == "multi" {
                let ps = ini["partSize"].int ?? 20 * 1024 * 1024, n = ini["parts"].int ?? 1
                var parts: [JSON] = []
                for p in 1...n {
                    guard let chunk = read((p - 1) * ps, ps) else { throw APIError(status: 0, message: "ما كدرت أقرأ الملف") }
                    let base = Double((p - 1) * ps)
                    let r = try await API.shared.upload("/files/\(id)/part/\(p)", data: chunk) { pr in
                        update { $0.progress = min(0.99, (base + pr * Double(chunk.count)) / Double(size)) }
                    }
                    parts.append(r["part"])
                }
                res = try await API.shared.post("/files/\(id)/complete", ["parts": .array(parts)])
            } else {
                guard let all = read(0, Int(size)) else { throw APIError(status: 0, message: "ما كدرت أقرأ الملف") }
                res = try await API.shared.upload("/files/\(id)/body", data: all) { pr in update { $0.progress = min(0.99, pr) } }
            }
            update { $0.progress = 1; $0.done = true; $0.file = res["file"] }
            Prefs.shared.notify(.success)
            onDone?(res["file"])
        } catch {
            update { $0.error = (error as? APIError)?.message ?? error.localizedDescription }
            Prefs.shared.notify(.error)
        }
    }
}

struct UploadJobsView: View {
    @ObservedObject var up: Uploader
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        ForEach(up.jobs) { j in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: j.error != nil ? "exclamationmark.triangle.fill" : j.done ? "checkmark.circle.fill" : "arrow.up.circle").foregroundStyle(j.error != nil ? prefs.theme.bad : j.done ? prefs.theme.ok : prefs.theme.accent)
                    Text(j.name).font(.ox(14, .medium)).lineLimit(1)
                    Spacer()
                    Text(j.error != nil ? "فشل" : "\(Int(j.progress * 100))%").font(.num(13, .semibold)).contentTransition(.numericText())
                }
                ProgressView(value: j.progress).tint(j.error != nil ? prefs.theme.bad : prefs.theme.ok)
                HStack {
                    Text(Fmt.bytes(Double(j.size))).font(.ox(11.5)).foregroundStyle(prefs.theme.mute)
                    if let e = j.error { Text(e).font(.ox(11.5)).foregroundStyle(prefs.theme.bad).lineLimit(2) }
                    Spacer()
                    if j.done, !j.file["url"].str.isEmpty {
                        Button { UIPasteboard.general.string = j.file["url"].str; Toasts.shared.show("انسخ الرابط") } label: { Label("انسخ الرابط", systemImage: "link") }.font(.ox(12.5)).buttonStyle(.borderless)
                    }
                }
            }.padding(.vertical, 4)
        }
    }
}

// MARK: - الملفات
struct FilesView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @StateObject private var r = Remote("/files")
    @StateObject private var up = Uploader()
    @State private var kind = "all"
    @State private var q = ""
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var del: JSON?
    @State private var rename: JSON?
    @State private var newName = ""
    let kinds: [(String, String, String)] = [("all", "الكل", "square.grid.2x2"), ("image", "صور", "photo"), ("video", "فيديو", "film"), ("audio", "صوت", "waveform"), ("doc", "ملفات", "doc.fill"), ("app", "تطبيقات", "app.badge"), ("other", "ثانية", "questionmark.folder")]

    var items: [JSON] {
        r.data["items"].arr.filter { (kind == "all" || $0["kind"].str == kind) && (q.isEmpty || $0["name"].str.localizedCaseInsensitiveContains(q)) }
    }
    var body: some View {
        let t = prefs.theme
        List {
            if r.error != nil && !r.loaded {
                Section { EmptyState(icon: "externaldrive.badge.xmark", text: "مخزن الملفات مو جاهز", sub: r.error) }
            }
            if r.loaded {
                Section { usage }
                if session.can("files.upload") {
                    Section {
                        HStack(spacing: 10) {
                            Button { importing = true } label: { Label("من الملفات", systemImage: "folder.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.oxGlass).accessibilityIdentifier("uploadFiles")
                            Button { showPhotos = true } label: { Label("من الصور", systemImage: "photo.badge.plus").frame(maxWidth: .infinity) }.buttonStyle(.oxGlass)
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                        UploadJobsView(up: up)
                    } footer: { Text("كل ملف ينطيك رابط تحميل مباشر. الملفات الكبيرة (فوق 90 ميغا) تنرفع على أجزاء تلقائيًا.").font(.ox(12)) }
                }
                Section {
                    Chips(options: kinds.map { ($0.0, $0.1) }, selection: $kind).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    if items.isEmpty { Text("ماكو ملفات").font(.ox(14)).foregroundStyle(t.mute) }
                    ForEach(items, id: \.self) { f in FileRow(f: f) { act in handle(act, f) } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $q, prompt: "ابحث باسم الملف")
        .overlay { if !r.loaded && r.error == nil { Loading() } }
        .oxScreen("الملفات", page: "files")
        .task { up.onDone = { _ in Task { await r.load() } }; await r.load() }
        .refreshable { await r.load() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { res in
            if case .success(let urls) = res { for u in urls { Task { await up.upload(url: u) } } }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photos, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
        .onChange(of: photos) { _, items in
            for it in items {
                Task {
                    if let d = try? await it.loadTransferable(type: Data.self) {
                        let ut = it.supportedContentTypes.first ?? .jpeg
                        let ext = ut.preferredFilenameExtension ?? "jpg"
                        await up.upload(data: d, name: "IMG-\(Int(Date().timeIntervalSince1970)).\(ext)", type: ut.preferredMIMEType ?? "image/jpeg")
                    }
                }
            }
            photos = []
        }
        .confirmationDialog("تحذف «\(del?["name"].str ?? "")»؟", isPresented: Binding(get: { del != nil }, set: { if !$0 { del = nil } }), titleVisibility: .visible) {
            Button("احذف نهائيًا", role: .destructive) { if let f = del { Task { await remove(f) } } }
        } message: { Text("الرابط يتعطل لكل من عنده.") }
        .alert("غيّر الاسم", isPresented: Binding(get: { rename != nil }, set: { if !$0 { rename = nil } })) {
            TextField("الاسم", text: $newName)
            Button("إلغاء", role: .cancel) {}
            Button("احفظ") { if let f = rename { Task { _ = try? await API.shared.post("/files/\(f["id"].str)/rename", ["name": .string(newName)]); await r.load() } } }
        }
    }

    var usage: some View {
        let u = r.data["usage"], t = prefs.theme
        let total = u["total"].double ?? 0, quota = max(1, u["quota"].double ?? 1)
        let colors: [String: Color] = ["image": t.info, "video": t.accent, "audio": t.ok, "doc": t.warn, "app": t.bad, "other": t.mute]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.bytes(total)).font(.num(26, .bold))
                Text("من \(Fmt.bytes(quota))").font(.ox(13)).foregroundStyle(t.mute)
                Spacer()
                Text("باقي \(Fmt.bytes(u["free"].double ?? 0))").font(.ox(13, .medium)).foregroundStyle(t.ok)
            }
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(u["byKind"].keys, id: \.self) { k in
                        Rectangle().fill(colors[k] ?? t.mute).frame(width: max(2, g.size.width * (u["byKind"][k]["size"].double ?? 0) / quota))
                    }
                    Spacer(minLength: 0)
                }.background(t.surface2).clipShape(Capsule())
            }.frame(height: 10)
            HStack(spacing: 12) {
                ForEach(u["byKind"].keys, id: \.self) { k in
                    HStack(spacing: 4) { Circle().fill(colors[k] ?? t.mute).frame(width: 7, height: 7); Text("\(kindName(k)) \(Fmt.n(u["byKind"][k]["n"]))").font(.ox(11.5)).foregroundStyle(t.mute) }
                }
            }
        }.padding(.vertical, 4)
    }
    func kindName(_ k: String) -> String { kinds.first { $0.0 == k }?.1 ?? k }

    func handle(_ act: String, _ f: JSON) {
        switch act {
        case "copy": UIPasteboard.general.string = f["url"].str; Toasts.shared.show("انسخ الرابط")
        case "open": if let u = URL(string: f["url"].str) { UIApplication.shared.open(u) }
        case "delete": del = f
        case "rename": newName = f["name"].str; rename = f
        default: break
        }
    }
    func remove(_ f: JSON) async {
        do { try await API.shared.post("/files/\(f["id"].str)/delete"); Toasts.shared.show("انحذف"); await r.load() } catch { Toasts.shared.error(error) }
    }
}

struct FileRow: View {
    let f: JSON
    var onAction: (String) -> Void
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    var icon: String { ["image": "photo.fill", "video": "film.fill", "audio": "waveform", "doc": "doc.fill", "app": "app.badge.fill"][f["kind"].str] ?? "doc" }
    var body: some View {
        HStack(spacing: 12) {
            if f["kind"].str == "image", let u = URL(string: f["url"].str) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.15) }
                    .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(prefs.theme.accent).frame(width: 44, height: 44).background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(f["name"].str).font(.ox(14.5, .medium)).lineLimit(1).truncationMode(.middle)
                Text("\(Fmt.bytes(f["size"].double ?? 0)) · \(Fmt.ago(f["at"].date)) · \(Fmt.n(f["downloads"])) تحميل").font(.ox(11.5)).foregroundStyle(prefs.theme.mute)
            }
            Spacer(minLength: 0)
            Menu {
                Button { onAction("copy") } label: { Label("انسخ رابط التحميل", systemImage: "link") }
                Button { onAction("open") } label: { Label("افتح بسفاري", systemImage: "safari") }
                ShareLink(item: URL(string: f["url"].str) ?? URL(string: "https://iraqfit.com")!) { Label("شارك", systemImage: "square.and.arrow.up") }
                if session.can("files.upload") { Button { onAction("rename") } label: { Label("غيّر الاسم", systemImage: "pencil") } }
                if session.can("files.delete") { Divider(); Button(role: .destructive) { onAction("delete") } label: { Label("حذف", systemImage: "trash") } }
            } label: { Image(systemName: "ellipsis.circle").font(.system(size: 20)).foregroundStyle(prefs.theme.mute) }
        }
        .contentShape(Rectangle())
        .onTapGesture { onAction("copy") }
    }
}
