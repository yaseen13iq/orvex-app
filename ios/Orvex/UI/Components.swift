import SwiftUI

// MARK: - الشعار
struct OrvexSymbol: View {
    var size: CGFloat = 44
    var color: Color? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        Image("OrvexSymbol").resizable().renderingMode(.template).scaledToFit()
            .foregroundStyle(color ?? prefs.theme.ink)
            .frame(width: size, height: size)
            .accessibilityLabel("أورفيكس")
    }
}
struct OrvexWordmark: View {
    var height: CGFloat = 18
    var color: Color? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        WordmarkShape().fill(color ?? prefs.theme.ink, style: FillStyle(eoFill: true)).frame(width: height * 5.5, height: height).accessibilityLabel("ORVEX")
    }
}
/// حروف ORVEX الرسمية (مرسومة من ملف الهوية)
struct WordmarkShape: Shape {
    /// الحروف اللاتينية ما تنعكس بالواجهة العربية
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }
    func path(in r: CGRect) -> Path {
        let sx = r.width / 550, sy = r.height / 100
        var p = Path()
        func T(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        // O
        p.addEllipse(in: CGRect(origin: T(0, -2), size: CGSize(width: 104 * sx, height: 104 * sy)))
        p.addEllipse(in: CGRect(origin: T(21, 19), size: CGSize(width: 62 * sx, height: 62 * sy)))
        // R
        p.addRect(CGRect(origin: T(141, 0), size: CGSize(width: 20 * sx, height: 100 * sy)))
        p.move(to: T(141, 0)); p.addLine(to: T(205, 0)); p.addLine(to: T(205, 28))
        p.addQuadCurve(to: T(177, 56), control: T(205, 56)); p.addLine(to: T(141, 56)); p.closeSubpath()
        p.move(to: T(161, 18)); p.addLine(to: T(161, 38)); p.addLine(to: T(177, 38)); p.addQuadCurve(to: T(185, 28), control: T(185, 38)); p.addLine(to: T(185, 18)); p.closeSubpath()
        p.move(to: T(167, 44)); p.addLine(to: T(189, 44)); p.addLine(to: T(215, 100)); p.addLine(to: T(193, 100)); p.closeSubpath()
        // V
        p.move(to: T(246, 0)); p.addLine(to: T(269, 0)); p.addLine(to: T(293, 52.6)); p.addLine(to: T(317, 0)); p.addLine(to: T(340, 0)); p.addLine(to: T(293, 103)); p.closeSubpath()
        // E
        p.addRect(CGRect(origin: T(369, 0), size: CGSize(width: 20 * sx, height: 100 * sy)))
        p.addRect(CGRect(origin: T(369, 0), size: CGSize(width: 60 * sx, height: 18 * sy)))
        p.addRect(CGRect(origin: T(369, 41), size: CGSize(width: 54 * sx, height: 18 * sy)))
        p.addRect(CGRect(origin: T(369, 82), size: CGSize(width: 60 * sx, height: 18 * sy)))
        // X
        p.move(to: T(460, 0)); p.addLine(to: T(483, 0)); p.addLine(to: T(550, 100)); p.addLine(to: T(527, 100)); p.closeSubpath()
        p.move(to: T(527, 0)); p.addLine(to: T(550, 0)); p.addLine(to: T(483, 100)); p.addLine(to: T(460, 100)); p.closeSubpath()
        return p
    }
}

// MARK: - الخلفية
struct ScreenBG: ViewModifier {
    @ObservedObject var prefs = Prefs.shared
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(prefs.theme.bg.ignoresSafeArea())
    }
}
extension View {
    func oxScreen(_ title: String, page: String? = nil) -> some View {
        modifier(ScreenBG()).navigationTitle(title).navigationBarTitleDisplayMode(.large)
            .toggleStyle(SwitchToggleStyle(tint: Prefs.shared.theme.ok))
            .onAppear { if let p = page { Session.shared.page = p } }
    }
}

// MARK: - البطاقة
struct Card<Content: View>: View {
    var title: String? = nil
    var icon: String? = nil
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    @ViewBuilder var content: () -> Content
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        VStack(alignment: .leading, spacing: prefs.d.density == "compact" ? 10 : 14) {
            if title != nil || icon != nil {
                HStack(spacing: 10) {
                    if let i = icon { Image(systemName: i).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.accent).frame(width: 30, height: 30).background(t.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous)) }
                    VStack(alignment: .leading, spacing: 1) {
                        if let s = title { Text(s).font(.ox(16, .semibold)).foregroundStyle(t.ink) }
                        if let s = subtitle { Text(s).font(.ox(12.5)).foregroundStyle(t.mute) }
                    }
                    Spacer(minLength: 0)
                    if let tr = trailing { tr }
                }
            }
            content()
        }
        .padding(prefs.pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(t.line))
    }
}

struct KPI: View {
    var title: String
    var value: String
    var icon: String
    var foot: String? = nil
    var tone: String? = nil
    var pulse = false
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if pulse { PulseDot(color: t.ok) } else { Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.mute) }
                Text(title).font(.ox(12.5)).foregroundStyle(t.mute).lineLimit(1)
            }
            Text(value).font(.num(28, .bold)).foregroundStyle(t.ink).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            if let f = foot { Text(f).font(.ox(11.5)).foregroundStyle(toneColor(tone, t) ?? t.mute).lineLimit(2) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(t.line))
        .accessibilityElement(children: .combine)
    }
}
func toneColor(_ tone: String?, _ t: AppTheme) -> Color? {
    switch tone { case "ok": return t.ok; case "warn": return t.warn; case "bad": return t.bad; case "info": return t.info; case "accent": return t.accent; case "mute": return t.mute; default: return nil }
}

struct PulseDot: View {
    var color: Color
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 2).scaleEffect(on ? 2.4 : 1).opacity(on ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true } }
    }
}

struct Pill: View {
    var text: String
    var tone: String = "mute"
    var icon: String? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let c = toneColor(tone, prefs.theme) ?? prefs.theme.mute
        HStack(spacing: 5) {
            if let i = icon { Image(systemName: i).font(.system(size: 10, weight: .bold)) } else { Circle().fill(c).frame(width: 6, height: 6) }
            Text(text).font(.ox(12, .medium)).lineLimit(1)
        }
        .foregroundStyle(c).padding(.horizontal, 10).padding(.vertical, 4)
        .background(c.opacity(0.14), in: Capsule())
    }
}

struct EmptyState: View {
    var icon: String
    var text: String
    var sub: String? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(prefs.theme.mute.opacity(0.7))
            Text(text).font(.ox(15, .medium)).foregroundStyle(prefs.theme.ink2)
            if let s = sub { Text(s).font(.ox(13)).foregroundStyle(prefs.theme.mute).multilineTextAlignment(.center) }
        }.frame(maxWidth: .infinity).padding(.vertical, 28)
    }
}

struct Loading: View {
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: 20, style: .continuous).fill(prefs.theme.surface).frame(height: 96).shimmer() }
        }.padding()
    }
}
struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.6).offset(x: x * g.size.width)
        }.clipped()).onAppear { withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { x = 1.4 } }
    }
}
extension View { func shimmer() -> some View { modifier(Shimmer()) } }

/// زر ينفّذ عملية غير متزامنة ويعرض مؤشر انتظار
struct AsyncButton<Label: View>: View {
    var role: ButtonRole? = nil
    var action: () async -> Void
    @ViewBuilder var label: () -> Label
    @State private var busy = false
    var body: some View {
        Button(role: role) {
            guard !busy else { return }
            busy = true; Prefs.shared.tap()
            Task { await action(); busy = false }
        } label: {
            ZStack { label().opacity(busy ? 0 : 1); if busy { ProgressView() } }
        }.disabled(busy)
    }
}

/// سطر قائمة بأيقونة
struct RowLabel: View {
    var title: String
    var icon: String
    var sub: String? = nil
    var tint: Color? = nil
    var badge: String? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        let t = prefs.theme
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint ?? t.accent)
                .frame(width: 34, height: 34).background((tint ?? t.accent).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ox(15, .medium)).foregroundStyle(t.ink)
                if let s = sub { Text(s).font(.ox(12)).foregroundStyle(t.mute).lineLimit(2) }
            }
            Spacer(minLength: 0)
            if let b = badge { Text(b).font(.num(12, .semibold)).foregroundStyle(t.onAccent).padding(.horizontal, 8).padding(.vertical, 2).background(t.accent, in: Capsule()) }
        }.padding(.vertical, 2)
    }
}

/// شريط الحفظ العائم (زجاج)
struct SaveBar: View {
    @ObservedObject var store = ConfigStore.shared
    @ObservedObject var prefs = Prefs.shared
    @State private var confirmDiscard = false
    var body: some View {
        if store.dirtyCount > 0 {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("تعديلات غير محفوظة").font(.ox(12)).foregroundStyle(prefs.theme.mute)
                    Text("\(Fmt.n(store.dirtyCount)) تعديل").font(.ox(15, .semibold)).foregroundStyle(prefs.theme.ink)
                }
                Spacer()
                Button("إلغاء") { confirmDiscard = true }.buttonStyle(.oxGlass)
                AsyncButton(action: { await store.save() }) { Label("احفظ", systemImage: "checkmark").font(.ox(15, .semibold)) }
                    .buttonStyle(.oxProminent)
                    .accessibilityIdentifier("saveBtn")
            }
            .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
            .glassRect(26)
            .padding(.horizontal, 14).padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .confirmationDialog("تلغي كل التعديلات غير المحفوظة؟", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("إلغاء التعديلات", role: .destructive) { store.discard() }
            }
        }
    }
}

/// طبقة التنبيهات المؤقتة
struct ToastLayer: View {
    @ObservedObject var toasts = Toasts.shared
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts.items) { it in
                HStack(spacing: 10) {
                    Image(systemName: it.kind == "bad" ? "exclamationmark.triangle.fill" : it.kind == "warn" ? "info.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(toneColor(it.kind == "bad" ? "bad" : it.kind == "warn" ? "warn" : "ok", prefs.theme) ?? .green)
                    Text(it.text).font(.ox(14, .medium)).foregroundStyle(prefs.theme.ink).lineLimit(3)
                    Spacer(minLength: 0)
                    if let a = it.actionTitle {
                        Button(a) { it.action?(); toasts.items.removeAll { $0.id == it.id } }.font(.ox(14, .semibold)).foregroundStyle(prefs.theme.accent)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .glassRect(20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }.padding(.horizontal, 14).frame(maxHeight: .infinity, alignment: .top).allowsHitTesting(!toasts.items.isEmpty)
    }
}

/// شريط أفقي من الخيارات
struct Chips: View {
    var options: [(String, String)]
    @Binding var selection: String
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { idx in let o = options[idx]
                    Button { withAnimation(.snappy) { selection = o.0 }; prefs.tap() } label: {
                        Text(o.1).font(.ox(13.5, selection == o.0 ? .semibold : .regular))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(selection == o.0 ? prefs.theme.onAccent : prefs.theme.ink2)
                            .background(selection == o.0 ? prefs.theme.accent : prefs.theme.surface, in: Capsule())
                            .overlay(Capsule().stroke(prefs.theme.line))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16)
        }
    }
}

/// شريط نسبة (بار)
struct BarRow: View {
    var name: String
    var value: Double
    var total: Double
    var max: Double
    var lead: String? = nil
    @ObservedObject var prefs = Prefs.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let l = lead { Text(l) }
                Text(name).font(.ox(14)).foregroundStyle(prefs.theme.ink).lineLimit(1)
                Spacer()
                Text(Fmt.n(value)).font(.num(13)).foregroundStyle(prefs.theme.ink2)
                Text("\(Int((value / Swift.max(total, 1) * 100).rounded()))%").font(.num(11)).foregroundStyle(prefs.theme.mute).frame(minWidth: 34, alignment: .trailing)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(prefs.theme.surface2)
                    Capsule().fill(prefs.theme.accent).frame(width: Swift.max(4, g.size.width * value / Swift.max(max, 1)))
                }
            }.frame(height: 6)
        }
    }
}

extension JSON {
    /// قائمة مرتبة تنازليًا من كائن عدّاد
    var sortedCounts: [(String, Double)] { (object?.pairs ?? []).map { ($0.0, $0.1.double ?? 0) }.sorted { $0.1 > $1.1 } }
}
