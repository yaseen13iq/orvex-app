import SwiftUI

// MARK: - الصفحة: عنوان كبير + سطر تعريفي + محتوى
struct Page<Content: View>: View {
    var title: String
    var intro: String? = nil
    var id: String = ""
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let i = intro, !i.isEmpty {
                    Text(i).font(.ox(14)).foregroundStyle(C.mute).lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.bottom, 6)
                }
                content()
            }
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(C.bg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { if !id.isEmpty { Session.shared.page = id } }
    }
}

/// عنوان مجموعة صغير فوق البطاقة
struct SectionTitle: View {
    var text: String
    var trailing: String? = nil
    init(_ text: String, trailing: String? = nil) { self.text = text; self.trailing = trailing }
    var body: some View {
        HStack {
            Text(text).font(.ox(13, .semibold)).foregroundStyle(C.mute)
            Spacer()
            if let t = trailing { Text(t).font(.ox(12)).foregroundStyle(C.mute) }
        }
        .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 8)
    }
}
/// ملاحظة أسفل البطاقة
struct SectionFooter: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.ox(12.5)).foregroundStyle(C.mute).lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22).padding(.top, 8)
    }
}

/// بطاقة بيضاء تضم صفوفًا مفصولة بخطوط رفيعة
struct Card<Content: View>: View {
    var padded = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content()) { subs in
                ForEach(Array(subs.enumerated()), id: \.element.id) { i, s in
                    if i > 0 && !padded { Rectangle().fill(C.line).frame(height: 1).padding(.leading, 16).padding(.trailing, 16) }
                    s
                }
            }
        }
        .padding(padded ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - مربع الأيقونة الملوّن
struct IconTile: View {
    var icon: String
    var color: String = "graphite"
    var size: CGFloat = 34
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(C.tiles[color] ?? C.mute, in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
    }
}

struct Pill: View {
    var text: String
    var tone: String = "mute"
    var body: some View {
        Text(text).font(.ox(12, .semibold)).lineLimit(1)
            .foregroundStyle(C.tone(tone))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(tone == "mute" ? C.fill : C.toneBG(tone), in: Capsule())
    }
}

// MARK: - الصفوف
/// محتوى صف: أيقونة + عنوان + وصف + قيمة على الطرف
struct RowContent: View {
    var title: String
    var sub: String? = nil
    var icon: String? = nil
    var color: String = "graphite"
    var value: String? = nil
    var pill: (String, String)? = nil
    var chevron = true
    var body: some View {
        HStack(spacing: 12) {
            if let i = icon { IconTile(icon: i, color: color) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ox(15.5, .medium)).foregroundStyle(C.ink).multilineTextAlignment(.leading)
                if let s = sub, !s.isEmpty { Text(s).font(.ox(12.5)).foregroundStyle(C.mute).lineLimit(2).multilineTextAlignment(.leading) }
            }
            Spacer(minLength: 8)
            if let p = pill { Pill(text: p.0, tone: p.1) }
            if let v = value { Text(v).font(.ox(13.5)).foregroundStyle(C.mute).lineLimit(1) }
            if chevron { Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.mute.opacity(0.6)) }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// صف ينقل إلى صفحة أخرى
struct NavRow<V: Hashable>: View {
    var value: V
    var title: String
    var sub: String? = nil
    var icon: String? = nil
    var color: String = "graphite"
    var trailing: String? = nil
    var pill: (String, String)? = nil
    var body: some View {
        NavigationLink(value: value) {
            RowContent(title: title, sub: sub, icon: icon, color: color, value: trailing, pill: pill)
        }
        .buttonStyle(RowPress())
        .accessibilityIdentifier("row-" + title)
    }
}

/// صف ينفّذ إجراءً
struct ActionRow: View {
    var title: String
    var icon: String
    var tone: String = "info"
    var action: () async -> Void
    @State private var busy = false
    var body: some View {
        Button {
            guard !busy else { return }
            busy = true
            Task { await action(); busy = false }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium)).frame(width: 26)
                Text(title).font(.ox(15.5, .medium))
                Spacer()
                if busy { ProgressView() }
            }
            .foregroundStyle(C.tone(tone))
            .padding(.horizontal, 14).frame(minHeight: 52).contentShape(Rectangle())
        }
        .buttonStyle(RowPress())
        .accessibilityIdentifier("action-" + title)
    }
}

struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? C.fill : Color.clear)
    }
}

/// صف معلومة: عنوان وقيمة
struct InfoRow: View {
    var title: String
    var value: String
    var tone: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.ox(15)).foregroundStyle(C.ink2)
            Spacer(minLength: 10)
            Text(value).font(.ox(14.5, .medium)).foregroundStyle(tone == nil ? C.ink : C.tone(tone)).multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.horizontal, 14).frame(minHeight: 50)
    }
}

/// صف بمفتاح تشغيل
struct ToggleRow: View {
    var title: String
    var sub: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ox(15.5, .medium)).foregroundStyle(C.ink)
                if let s = sub, !s.isEmpty { Text(s).font(.ox(12.5)).foregroundStyle(C.mute).lineSpacing(1) }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: C.ok))
        .padding(.horizontal, 14).padding(.vertical, 9).frame(minHeight: 54)
    }
}

// MARK: - الأزرار
struct PrimaryButton: View {
    var title: String
    var icon: String? = nil
    var tone: String? = nil
    var disabled = false
    var action: () async -> Void
    @State private var busy = false
    var body: some View {
        Button {
            guard !busy else { return }
            busy = true; Haptics.tap()
            Task { await action(); busy = false }
        } label: {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(tone == nil ? C.onPrimary : .white) }
                else if let i = icon { Image(systemName: i).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(.ox(16, .semibold))
            }
            .foregroundStyle(tone == nil ? C.onPrimary : .white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(tone == nil ? C.primary : C.tone(tone), in: Capsule())
            .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled || busy)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("btn-" + title)
    }
}

// MARK: - مؤشرات الأرقام
struct KPI: View {
    var title: String
    var value: String
    var foot: String? = nil
    var tone: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.ox(12.5)).foregroundStyle(C.mute).lineLimit(1)
            Text(value).font(.num(25)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            if let f = foot { Text(f).font(.ox(11.5)).foregroundStyle(C.tone(tone ?? "mute")).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
struct KPIGrid<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.horizontalSizeClass) var hs
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: hs == .regular ? 4 : 2), spacing: 10) { content() }
            .padding(.horizontal, 16)
    }
}

/// شريط نسبة لقوائم الإحصاءات
struct BarRow: View {
    var name: String
    var value: Double
    var total: Double
    var max: Double
    var lead: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let l = lead { Text(l).font(.system(size: 17)) }
                Text(name).font(.ox(14.5)).foregroundStyle(C.ink).lineLimit(1)
                Spacer()
                Text(Fmt.n(value)).font(.ox(14, .semibold)).foregroundStyle(C.ink)
                Text(total > 0 ? Fmt.percent(value / total) : "").font(.ox(12)).foregroundStyle(C.mute).frame(minWidth: 38, alignment: .trailing)
            }
            GeometryReader { g in
                Capsule().fill(C.fill).overlay(alignment: .leading) {
                    Capsule().fill(C.ink.opacity(0.75)).frame(width: g.size.width * (max > 0 ? value / max : 0))
                }
            }.frame(height: 5)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

/// صندوق تنبيه أو شرح
struct Note: View {
    var text: String
    var tone: String = "info"
    var icon: String = "info.circle.fill"
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(C.tone(tone)).padding(.top, 1)
            Text(text).font(.ox(13)).foregroundStyle(C.ink2).lineSpacing(2).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(C.toneBG(tone), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - الحالات
struct EmptyState: View {
    var icon: String
    var title: String
    var sub: String? = nil
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(C.mute)
            Text(title).font(.ox(16, .semibold)).foregroundStyle(C.ink)
            if let s = sub { Text(s).font(.ox(13.5)).foregroundStyle(C.mute).multilineTextAlignment(.center).lineSpacing(2) }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 30)
    }
}
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) { ProgressView(); Text("جارٍ التحميل…").font(.ox(13)).foregroundStyle(C.mute) }
            .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
/// يعرض التحميل أو الخطأ أو المحتوى لبيانات من الخادم
struct RemoteBody<Content: View>: View {
    @ObservedObject var r: Remote
    @ViewBuilder var content: () -> Content
    var body: some View {
        if r.loaded { content() }
        else if let e = r.error {
            VStack(spacing: 6) {
                EmptyState(icon: "wifi.exclamationmark", title: "تعذّر تحميل هذه الصفحة", sub: e)
                PrimaryButton(title: "إعادة المحاولة", icon: "arrow.clockwise") { await r.load() }.frame(maxWidth: 260)
            }
        } else { LoadingView() }
    }
}

// MARK: - اختيار من شرائح
struct Chips: View {
    var options: [(String, String)]
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let o = options[i], on = selection == o.0
                    Button { withAnimation(.snappy) { selection = o.0 }; Haptics.tap() } label: {
                        Text(o.1).font(.ox(13.5, on ? .semibold : .regular))
                            .foregroundStyle(on ? C.onPrimary : C.ink2)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(on ? C.primary : C.card, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 16)
        }
    }
}

// MARK: - الشعار
struct OrvexSymbol: View {
    var size: CGFloat = 44
    var color: Color = C.ink
    var body: some View {
        Image("OrvexSymbol").resizable().renderingMode(.template).scaledToFit()
            .foregroundStyle(color).frame(width: size, height: size).accessibilityLabel("أورفيكس")
    }
}
struct OrvexWordmark: View {
    var height: CGFloat = 16
    var color: Color = C.ink
    var body: some View {
        ZStack {
            WordmarkShape(ring: true).fill(color, style: FillStyle(eoFill: true))
            WordmarkShape(ring: false).fill(color)
        }
        .frame(width: height * 5.5, height: height)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityLabel("ORVEX")
    }
}
/// حروف ORVEX كما في ملف الهوية (الحلقة O منفصلة لتُفرَّغ من الداخل)
struct WordmarkShape: Shape {
    var ring: Bool
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }
    func path(in r: CGRect) -> Path {
        let sx = r.width / 550, sy = r.height / 100
        var p = Path()
        func T(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        if ring {
            p.addEllipse(in: CGRect(origin: T(0, -2), size: CGSize(width: 104 * sx, height: 104 * sy)))
            p.addEllipse(in: CGRect(origin: T(21, 19), size: CGSize(width: 62 * sx, height: 62 * sy)))
            return p
        }
        // R
        p.addRect(CGRect(origin: T(141, 0), size: CGSize(width: 20 * sx, height: 100 * sy)))
        p.move(to: T(161, 0)); p.addLine(to: T(205, 0)); p.addLine(to: T(205, 28))
        p.addQuadCurve(to: T(177, 56), control: T(205, 56)); p.addLine(to: T(161, 56)); p.addLine(to: T(161, 38))
        p.addLine(to: T(177, 38)); p.addQuadCurve(to: T(185, 28), control: T(185, 38)); p.addLine(to: T(185, 18)); p.addLine(to: T(161, 18)); p.closeSubpath()
        p.move(to: T(172, 56)); p.addLine(to: T(194, 56)); p.addLine(to: T(215, 100)); p.addLine(to: T(193, 100)); p.closeSubpath()
        // V
        p.move(to: T(246, 0)); p.addLine(to: T(269, 0)); p.addLine(to: T(293, 52.6)); p.addLine(to: T(317, 0)); p.addLine(to: T(340, 0)); p.addLine(to: T(293, 103)); p.closeSubpath()
        // E
        p.addRect(CGRect(origin: T(369, 0), size: CGSize(width: 20 * sx, height: 100 * sy)))
        p.addRect(CGRect(origin: T(389, 0), size: CGSize(width: 40 * sx, height: 18 * sy)))
        p.addRect(CGRect(origin: T(389, 41), size: CGSize(width: 34 * sx, height: 18 * sy)))
        p.addRect(CGRect(origin: T(389, 82), size: CGSize(width: 40 * sx, height: 18 * sy)))
        // X
        p.move(to: T(460, 0)); p.addLine(to: T(483, 0)); p.addLine(to: T(550, 100)); p.addLine(to: T(527, 100)); p.closeSubpath()
        p.move(to: T(527, 0)); p.addLine(to: T(550, 0)); p.addLine(to: T(483, 100)); p.addLine(to: T(460, 100)); p.closeSubpath()
        return p
    }
}

// MARK: - شريط الحفظ
struct SaveBar: View {
    @ObservedObject var store = ConfigStore.shared
    @State private var askDiscard = false
    var body: some View {
        if store.dirtyCount > 0 {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.dirtyCount == 1 ? "تعديل واحد غير محفوظ" : store.dirtyCount == 2 ? "تعديلان غير محفوظين" : "\(Fmt.n(store.dirtyCount)) تعديلات غير محفوظة")
                        .font(.ox(14, .semibold)).foregroundStyle(.white)
                    Text(store.summary).font(.ox(11.5)).foregroundStyle(Color(hex: 0xB9BFC8)).lineLimit(1)
                }
                Spacer(minLength: 6)
                Button { askDiscard = true } label: {
                    Text("إلغاء").font(.ox(14)).foregroundStyle(.white).padding(.horizontal, 14).frame(height: 44).background(.white.opacity(0.14), in: Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("discardBtn")
                Button { Task { await store.save() } } label: {
                    HStack(spacing: 6) {
                        if store.saving { ProgressView().tint(.black) }
                        Text("حفظ").font(.ox(15, .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x0B0C0E)).padding(.horizontal, 20).frame(height: 44).background(.white, in: Capsule())
                }.buttonStyle(.plain).disabled(store.saving).accessibilityIdentifier("saveBtn")
            }
            .padding(.leading, 18).padding(.trailing, 8).frame(height: 62)
            .background(Color(hex: 0x0B0C0E), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .padding(.horizontal, 14).padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .confirmationDialog("إلغاء التعديلات غير المحفوظة؟", isPresented: $askDiscard, titleVisibility: .visible) {
                Button("إلغاء التعديلات", role: .destructive) { withAnimation { store.discard() } }
                Button("متابعة التعديل", role: .cancel) {}
            }
        }
    }
}

// MARK: - الرسائل المؤقتة
struct ToastLayer: View {
    @ObservedObject var t = Toasts.shared
    var body: some View {
        VStack(spacing: 8) {
            ForEach(t.items) { it in
                HStack(spacing: 10) {
                    Image(systemName: it.kind == "bad" ? "xmark.octagon.fill" : it.kind == "warn" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(it.kind == "bad" ? Color(hex: 0xF0626A) : it.kind == "warn" ? Color(hex: 0xF0B44C) : Color(hex: 0x3DD68C))
                    Text(it.text).font(.ox(14)).foregroundStyle(.white).lineLimit(3)
                    Spacer(minLength: 4)
                    if let a = it.actionTitle {
                        Button { it.action?(); withAnimation { t.items.removeAll { $0.id == it.id } } } label: {
                            Text(a).font(.ox(14, .semibold)).foregroundStyle(Color(hex: 0x7DA6F0))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(Color(hex: 0x1F2227), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14).padding(.top, 6)
        .frame(maxWidth: 560)
    }
}
