import Foundation

/// قيمة JSON ديناميكية تحافظ على ترتيب المفاتيح (حتى تنعرض الحقول بنفس ترتيب الموقع)
public enum JSON: Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object(JObject)

    // MARK: قراءة مختصرة
    public subscript(key: String) -> JSON {
        get { if case .object(let o) = self { return o[key] ?? .null }; return .null }
        set {
            if case .object(var o) = self { o[key] = newValue; self = .object(o) }
            else if case .null = self { var o = JObject(); o[key] = newValue; self = .object(o) }
        }
    }
    public subscript(index: Int) -> JSON {
        get { if case .array(let a) = self, index >= 0, index < a.count { return a[index] }; return .null }
        set { if case .array(var a) = self, index >= 0, index < a.count { a[index] = newValue; self = .array(a) } }
    }
    public var string: String? { if case .string(let s) = self { return s }; return nil }
    public var str: String { switch self { case .string(let s): return s; case .number(let n): return JSON.fmt(n); case .bool(let b): return b ? "true" : "false"; default: return "" } }
    public var double: Double? { if case .number(let n) = self { return n }; if case .string(let s) = self { return Double(s) }; return nil }
    public var int: Int? { double.map { Int($0) } }
    public var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var isTrue: Bool { bool == true }
    public var array: [JSON]? { if case .array(let a) = self { return a }; return nil }
    public var arr: [JSON] { array ?? [] }
    public var object: JObject? { if case .object(let o) = self { return o }; return nil }
    public var keys: [String] { object?.keys ?? [] }
    public var isNull: Bool { if case .null = self { return true }; return false }
    public var isObject: Bool { object != nil }
    public var isArray: Bool { array != nil }
    /// نص ثنائي اللغة {ar, en}
    public var isI18n: Bool {
        guard let o = object, !o.keys.isEmpty else { return false }
        return o.keys.allSatisfy { $0 == "ar" || $0 == "en" }
    }
    public var ar: String { self["ar"].string ?? self["en"].string ?? (string ?? "") }
    public var text: String { isI18n ? ar : str }
    public var date: Date? { double.map { Date(timeIntervalSince1970: $0 / 1000) } }

    public static func fmt(_ n: Double) -> String {
        if n.rounded() == n && abs(n) < 1e15 { return String(Int64(n)) }
        return String(n)
    }

    // MARK: المسارات
    public func at(_ path: [Seg]) -> JSON {
        var cur = self
        for s in path {
            switch s {
            case .key(let k): cur = cur[k]
            case .index(let i): cur = cur[i]
            }
        }
        return cur
    }
    public mutating func set(_ path: [Seg], _ value: JSON?) {
        guard let first = path.first else { if let v = value { self = v }; return }
        let rest = Array(path.dropFirst())
        switch first {
        case .key(let k):
            var o = object ?? JObject()
            if rest.isEmpty { if let v = value { o[k] = v } else { o.remove(k) } }
            else { var child = o[k] ?? .null; child.set(rest, value); o[k] = child }
            self = .object(o)
        case .index(let i):
            guard var a = array, i >= 0 else { return }
            if rest.isEmpty {
                if let v = value { if i < a.count { a[i] = v } else if i == a.count { a.append(v) } } else if i < a.count { a.remove(at: i) }
            } else if i < a.count { var child = a[i]; child.set(rest, value); a[i] = child }
            self = .array(a)
        }
    }
}

public enum Seg: Hashable, CustomStringConvertible {
    case key(String)
    case index(Int)
    public var description: String { switch self { case .key(let k): return k; case .index(let i): return String(i) } }
    public var json: JSON { switch self { case .key(let k): return .string(k); case .index(let i): return .number(Double(i)) } }
    public var keyName: String? { if case .key(let k) = self { return k }; return nil }
}
public func P(_ parts: Any...) -> [Seg] { parts.map { ($0 as? Int).map { Seg.index($0) } ?? Seg.key(String(describing: $0)) } }
public func pathKey(_ p: [Seg]) -> String { p.map(\.description).joined(separator: "\u{1F}") }
public func pathFromJSON(_ j: JSON) -> [Seg] { j.arr.map { $0.string.map(Seg.key) ?? Seg.index($0.int ?? 0) } }

/// كائن مرتّب
public struct JObject: Hashable {
    public private(set) var keys: [String] = []
    private var dict: [String: JSON] = [:]
    public init() {}
    public init(_ pairs: [(String, JSON)]) { for (k, v) in pairs { self[k] = v } }
    public subscript(key: String) -> JSON? {
        get { dict[key] }
        set {
            if let v = newValue { if dict[key] == nil { keys.append(key) }; dict[key] = v }
            else { remove(key) }
        }
    }
    public mutating func remove(_ key: String) { if dict.removeValue(forKey: key) != nil { keys.removeAll { $0 == key } } }
    public var pairs: [(String, JSON)] { keys.map { ($0, dict[$0]!) } }
    public var count: Int { keys.count }
    public static func == (a: JObject, b: JObject) -> Bool { a.dict == b.dict }
    public func hash(into h: inout Hasher) { h.combine(dict) }
}

extension JSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral, ExpressibleByNilLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(stringLiteral v: String) { self = .string(v) }
    public init(integerLiteral v: Int) { self = .number(Double(v)) }
    public init(booleanLiteral v: Bool) { self = .bool(v) }
    public init(floatLiteral v: Double) { self = .number(v) }
    public init(nilLiteral: ()) { self = .null }
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSON)...) { self = .object(JObject(elements)) }
    public static func i18n(_ ar: String, _ en: String = "") -> JSON { ["ar": .string(ar), "en": .string(en)] }
}

// MARK: - تحليل وكتابة (يحافظ على الترتيب)
public enum JSONCodec {
    public struct ParseError: Error {}
    public static func parse(_ data: Data) throws -> JSON {
        var p = Parser(bytes: [UInt8](data))
        p.skip()
        let v = try p.value()
        return v
    }
    public static func parse(_ s: String) throws -> JSON { try parse(Data(s.utf8)) }

    public static func encode(_ v: JSON, pretty: Bool = false) -> Data { Data(string(v, pretty: pretty).utf8) }
    public static func string(_ v: JSON, pretty: Bool = false, indent: Int = 0) -> String {
        let nl = pretty ? "\n" : "", pad = pretty ? String(repeating: "  ", count: indent + 1) : "", end = pretty ? String(repeating: "  ", count: indent) : ""
        switch v {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return n.isFinite ? JSON.fmt(n) : "null"
        case .string(let s): return quote(s)
        case .array(let a):
            if a.isEmpty { return "[]" }
            return "[" + nl + a.map { pad + string($0, pretty: pretty, indent: indent + 1) }.joined(separator: "," + nl) + nl + end + "]"
        case .object(let o):
            if o.count == 0 { return "{}" }
            return "{" + nl + o.pairs.map { pad + quote($0.0) + (pretty ? ": " : ":") + string($0.1, pretty: pretty, indent: indent + 1) }.joined(separator: "," + nl) + nl + end + "}"
        }
    }
    static func quote(_ s: String) -> String {
        var r = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": r += "\\\""
            case "\\": r += "\\\\"
            case "\n": r += "\\n"
            case "\r": r += "\\r"
            case "\t": r += "\\t"
            default:
                if u.value < 0x20 { r += String(format: "\\u%04x", u.value) } else { r.unicodeScalars.append(u) }
            }
        }
        return r + "\""
    }

    struct Parser {
        let bytes: [UInt8]
        var i = 0
        mutating func skip() { while i < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[i]) { i += 1 } }
        mutating func value() throws -> JSON {
            skip()
            guard i < bytes.count else { throw ParseError() }
            switch bytes[i] {
            case UInt8(ascii: "{"):
                i += 1; var o = JObject(); skip()
                if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
                while true {
                    skip(); let k = try str(); skip()
                    guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw ParseError() }
                    i += 1; let v = try value(); o[k] = v; skip()
                    guard i < bytes.count else { throw ParseError() }
                    if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                    if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
                    throw ParseError()
                }
            case UInt8(ascii: "["):
                i += 1; var a: [JSON] = []; skip()
                if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
                while true {
                    a.append(try value()); skip()
                    guard i < bytes.count else { throw ParseError() }
                    if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                    if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
                    throw ParseError()
                }
            case UInt8(ascii: "\""): return .string(try str())
            case UInt8(ascii: "t"): i += 4; return .bool(true)
            case UInt8(ascii: "f"): i += 5; return .bool(false)
            case UInt8(ascii: "n"): i += 4; return .null
            default:
                let s = i
                while i < bytes.count, "+-0123456789.eE".utf8.contains(bytes[i]) { i += 1 }
                guard let d = Double(String(decoding: bytes[s..<i], as: UTF8.self)) else { throw ParseError() }
                return .number(d)
            }
        }
        mutating func str() throws -> String {
            guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw ParseError() }
            i += 1
            var out = [UInt8]()
            while i < bytes.count {
                let c = bytes[i]
                if c == UInt8(ascii: "\"") { i += 1; return String(decoding: out, as: UTF8.self) }
                if c == UInt8(ascii: "\\") {
                    i += 1; guard i < bytes.count else { throw ParseError() }
                    let e = bytes[i]
                    switch e {
                    case UInt8(ascii: "n"): out.append(0x0A)
                    case UInt8(ascii: "r"): out.append(0x0D)
                    case UInt8(ascii: "t"): out.append(0x09)
                    case UInt8(ascii: "b"): out.append(0x08)
                    case UInt8(ascii: "f"): out.append(0x0C)
                    case UInt8(ascii: "u"):
                        guard i + 4 < bytes.count, var code = UInt32(String(decoding: bytes[(i + 1)...(i + 4)], as: UTF8.self), radix: 16) else { throw ParseError() }
                        i += 4
                        if code >= 0xD800 && code < 0xDC00, i + 6 < bytes.count, bytes[i + 1] == UInt8(ascii: "\\"), bytes[i + 2] == UInt8(ascii: "u"),
                           let lo = UInt32(String(decoding: bytes[(i + 3)...(i + 6)], as: UTF8.self), radix: 16), lo >= 0xDC00 && lo < 0xE000 {
                            code = 0x10000 + ((code - 0xD800) << 10) + (lo - 0xDC00); i += 6
                        }
                        let sc = Unicode.Scalar(code) ?? "?"
                        out.append(contentsOf: Array(String(Character(sc)).utf8))
                    default: out.append(e)
                    }
                    i += 1
                } else { out.append(c); i += 1 }
            }
            throw ParseError()
        }
    }
}
