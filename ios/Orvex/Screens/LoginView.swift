import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: Session
    @ObservedObject var prefs = Prefs.shared
    @State private var user = Vault.get("lastUser") ?? ""
    @State private var pass = ""
    @State private var showPass = false
    @State private var error: String?
    @State private var busy = false
    @State private var showServer = false
    @State private var server = API.shared.base
    @FocusState private var focus: Field?
    enum Field { case user, pass }

    var body: some View {
        let t = prefs.theme
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    OrvexSymbol(size: 84)
                    OrvexWordmark(height: 20, color: t.ink2)
                    Text("لوحة تحكم iraqfit.com").font(.ox(15)).foregroundStyle(t.mute)
                }.padding(.top, 60)

                VStack(spacing: 14) {
                    field(icon: "person.fill") {
                        TextField("اسم المستخدم", text: $user)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textContentType(.username).focused($focus, equals: .user)
                            .environment(\.layoutDirection, .leftToRight).multilineTextAlignment(.trailing)
                            .submitLabel(.next).onSubmit { focus = .pass }
                            .accessibilityIdentifier("username")
                    }
                    field(icon: "lock.fill") {
                        Group {
                            if showPass { TextField("كلمة السر", text: $pass) } else { SecureField("كلمة السر", text: $pass) }
                        }
                        .textContentType(.password).focused($focus, equals: .pass)
                        .submitLabel(.go).onSubmit { submit() }
                        .accessibilityIdentifier("password")
                        Button { showPass.toggle() } label: { Image(systemName: showPass ? "eye.slash" : "eye").foregroundStyle(t.mute) }
                    }
                    if let e = error {
                        Label(e, systemImage: "exclamationmark.circle.fill").font(.ox(13.5)).foregroundStyle(t.bad)
                            .frame(maxWidth: .infinity, alignment: .leading).transition(.opacity)
                    }
                    Button(action: submit) {
                        ZStack { Text("دخول").opacity(busy ? 0 : 1); if busy { ProgressView().tint(t.onAccent) } }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.oxProminent).disabled(busy || user.isEmpty || pass.isEmpty)
                    .accessibilityIdentifier("loginBtn")
                }
                .padding(20)
                .background(t.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(t.line))

                Button { showServer.toggle() } label: { Label("إعدادات الخادم", systemImage: "server.rack").font(.ox(13)) }.foregroundStyle(t.mute)
                if showServer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("رابط الموقع").font(.ox(13)).foregroundStyle(t.mute)
                        TextField("https://iraqfit.com", text: $server).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            .environment(\.layoutDirection, .leftToRight).padding(12)
                            .background(t.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button("احفظ الرابط") { API.shared.setBase(server); Toasts.shared.show("انحفظ") }.font(.ox(14, .semibold))
                    }.padding(16).background(t.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                VStack(spacing: 6) {
                    Text("تصميم وتطوير ياسين محمد").font(.ox(13, .medium)).foregroundStyle(t.ink2)
                    HStack(spacing: 6) { OrvexSymbol(size: 13, color: t.mute); Text("ORVEX · POWERING POSSIBILITIES").font(.num(10, .medium)).foregroundStyle(t.mute) }
                }.padding(.top, 10).padding(.bottom, 30)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.snappy, value: error)
        .animation(.snappy, value: showServer)
    }

    @ViewBuilder func field<C: View>(icon: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(prefs.theme.mute).frame(width: 20)
            c()
        }
        .font(.ox(16))
        .padding(.horizontal, 16).frame(height: 54)
        .background(prefs.theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func submit() {
        guard !busy, !user.isEmpty, !pass.isEmpty else { return }
        busy = true; error = nil; focus = nil
        Task {
            do { try await session.login(username: user, password: pass); pass = "" }
            catch { self.error = (error as? APIError)?.message ?? error.localizedDescription; Prefs.shared.notify(.error) }
            busy = false
        }
    }
}
