import Foundation
import UIKit

struct APIError: LocalizedError {
    var status: Int
    var message: String
    var data: JSON = .null
    var errorDescription: String? { message }
    var needsConfirm: Bool { status == 428 || (status == 403 && data["confirm"].isTrue) }
}

extension Notification.Name {
    static let orvexUnauthorized = Notification.Name("orvex.unauthorized")
    static let orvexKilled = Notification.Name("orvex.killed")
}

/// الاتصال بالخادم. جميع الطلبات بترويسة Bearer.
final class API {
    static let shared = API()
    var token: String? { didSet { Vault.set("token", token) } }
    var base: String
    /// يُستدعى عندما يطلب الخادم تأكيد إجراء حسّاس (يعيد كلمة المرور أو nil عند الإلغاء)
    var confirmProvider: ((Bool) async -> String?)?
    let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpAdditionalHeaders = ["User-Agent": "ORVEX-iOS/\(Bundle.main.version) (\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion))"]
        session = URLSession(configuration: cfg)
        let env = ProcessInfo.processInfo.environment["ORVEX_API"] ?? UserDefaults.standard.string(forKey: "orvex.base")
        base = (env?.isEmpty == false ? env! : (Bundle.main.object(forInfoDictionaryKey: "OrvexAPI") as? String) ?? "https://iraqfit.com").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        token = Vault.get("token")
    }
    func setBase(_ s: String) {
        let v = s.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        base = v
        UserDefaults.standard.set(v, forKey: "orvex.base")
    }

    func url(_ path: String) -> URL { URL(string: base + "/admin/api" + path)! }

    @discardableResult
    func get(_ path: String) async throws -> JSON { try await send("GET", path, body: nil) }
    @discardableResult
    func post(_ path: String, _ body: JSON = [:]) async throws -> JSON { try await send("POST", path, body: body) }

    /// يرسل الطلب، وإذا طلب الخادم تأكيدًا يسأل المستخدم ثم يعيد المحاولة
    func send(_ method: String, _ path: String, body: JSON?, raw: Data? = nil, retried: Bool = false) async throws -> JSON {
        var r = URLRequest(url: url(path))
        r.httpMethod = method
        if let t = token { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        if let b = body { r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = JSONCodec.encode(b) }
        if let d = raw { r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type"); r.httpBody = d }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await session.data(for: r) } catch {
            if (error as NSError).code == NSURLErrorCancelled { throw CancellationError() }
            throw APIError(status: 0, message: "تعذّر الاتصال بالخادم. تحقّق من اتصال الإنترنت ثم أعد المحاولة.")
        }
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let j = (try? JSONCodec.parse(data)) ?? .null
        if (200..<300).contains(status), j["ok"].bool != false { return j }
        let msg = j["error"].string ?? "حدث خطأ في الخادم (\(status))."
        if status == 401, j["auth"].isTrue {
            await MainActor.run { NotificationCenter.default.post(name: .orvexUnauthorized, object: nil) }
        }
        if status == 423, j["killed"].isTrue {
            await MainActor.run { NotificationCenter.default.post(name: .orvexKilled, object: msg) }
        }
        let err = APIError(status: status, message: msg, data: j)
        if err.needsConfirm, !retried, method == "POST", let ask = confirmProvider {
            if let code = await ask(j["pin"].isTrue) {
                var b: JSON = body ?? .object(JObject())
                b["confirm"] = .string(code)
                return try await send(method, path, body: b, raw: raw, retried: status == 403)
            }
            throw APIError(status: 499, message: "أُلغي التأكيد.")
        }
        throw err
    }

    /// رفع البيانات مع إظهار نسبة التقدّم
    func upload(_ path: String, data: Data, progress: @escaping (Double) -> Void) async throws -> JSON {
        var r = URLRequest(url: url(path))
        r.httpMethod = "PUT"
        if let t = token { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = 600
        let delegate = UploadDelegate(progress)
        let (d, resp) = try await session.upload(for: r, from: data, delegate: delegate)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let j = (try? JSONCodec.parse(d)) ?? .null
        guard (200..<300).contains(status), j["ok"].bool != false else { throw APIError(status: status, message: j["error"].string ?? "تعذّر رفع الملف (\(status)).", data: j) }
        return j
    }

    func download(_ url: URL) async throws -> URL {
        var r = URLRequest(url: url)
        if let t = token { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        let (tmp, resp) = try await session.download(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError(status: (resp as? HTTPURLResponse)?.statusCode ?? 0, message: "تعذّر تنزيل الملف.") }
        let name = (resp as? HTTPURLResponse)?.suggestedFilename ?? url.lastPathComponent
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest
    }
}

final class UploadDelegate: NSObject, URLSessionTaskDelegate {
    let cb: (Double) -> Void
    init(_ cb: @escaping (Double) -> Void) { self.cb = cb }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let p = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async { self.cb(p) }
    }
}

extension Bundle {
    var version: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0" }
    var build: Int { Int((infoDictionary?["CFBundleVersion"] as? String) ?? "1") ?? 1 }
}
