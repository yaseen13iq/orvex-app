import SwiftUI
import UniformTypeIdentifiers

/// تحميل بيانات من الخادم مع تحديث دوري اختياري
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



// MARK: - رفع الملفات (يستخدم في الملفات وتحديثات التطبيق)
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
            guard size > 0 else { throw APIError(status: 0, message: "الملف فارغ.") }
            let ini = try await API.shared.post("/files/init", ["name": .string(name), "size": .number(Double(size)), "type": .string(type)])
            let id = ini["id"].str
            var res: JSON
            if ini["mode"].str == "multi" {
                let ps = ini["partSize"].int ?? 20 * 1024 * 1024, n = ini["parts"].int ?? 1
                var parts: [JSON] = []
                for p in 1...n {
                    guard let chunk = read((p - 1) * ps, ps) else { throw APIError(status: 0, message: "تعذّرت قراءة الملف.") }
                    let base = Double((p - 1) * ps)
                    let r = try await API.shared.upload("/files/\(id)/part/\(p)", data: chunk) { pr in
                        update { $0.progress = min(0.99, (base + pr * Double(chunk.count)) / Double(size)) }
                    }
                    parts.append(r["part"])
                }
                res = try await API.shared.post("/files/\(id)/complete", ["parts": .array(parts)])
            } else {
                guard let all = read(0, Int(size)) else { throw APIError(status: 0, message: "تعذّرت قراءة الملف.") }
                res = try await API.shared.upload("/files/\(id)/body", data: all) { pr in update { $0.progress = min(0.99, pr) } }
            }
            update { $0.progress = 1; $0.done = true; $0.file = res["file"] }
            Haptics.notify(.success)
            onDone?(res["file"])
        } catch {
            update { $0.error = (error as? APIError)?.message ?? error.localizedDescription }
            Haptics.notify(.error)
        }
    }
}

