import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: Session
    @State private var username = UserDefaults.standard.string(forKey: "orvex.lastUser") ?? ""
    @State private var password = ""
    @State private var showPass = false
    @State private var error: String?
    @State private var showServer = false
    @State private var server = API.shared.base
    @FocusState private var focus: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 70)
                OrvexSymbol(size: 62)
                OrvexWordmark(height: 15).padding(.top, 16)
                Text("لوحة إدارة iraqfit.com").font(.ox(15)).foregroundStyle(C.mute).padding(.top, 12)

                VStack(spacing: 12) {
                    field(icon: "person", placeholder: "اسم المستخدم", text: $username, secure: false, tag: 0)
                        .textContentType(.username)
                        .accessibilityIdentifier("username")
                    field(icon: "lock", placeholder: "كلمة المرور", text: $password, secure: !showPass, tag: 1)
                        .textContentType(.password)
                        .accessibilityIdentifier("password")
                    if let e = error {
                        Label(e, systemImage: "exclamationmark.circle.fill").font(.ox(13.5)).foregroundStyle(C.bad)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                    }
                    PrimaryButton(title: "تسجيل الدخول", disabled: username.count < 2 || password.isEmpty) { await login() }
                        .padding(.horizontal, -16).padding(.top, 6)
                        .accessibilityIdentifier("loginBtn")
                }
                .padding(20)
                .background(C.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 18).padding(.top, 34)

                Button { showServer.toggle() } label: {
                    Label("عنوان الخادم", systemImage: "server.rack").font(.ox(13)).foregroundStyle(C.mute)
                }.padding(.top, 18)
                if showServer {
                    HStack {
                        TextField("https://iraqfit.com", text: $server).font(.ox(14)).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .environment(\.layoutDirection, .leftToRight)
                        Button("حفظ") { API.shared.setBase(server); showServer = false }.font(.ox(14, .semibold))
                    }
                    .padding(12).background(C.card, in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 18).padding(.top, 8)
                }
                Spacer(minLength: 60)
                VStack(spacing: 6) {
                    Text("تصميم وتطوير ياسين محمد").font(.ox(13, .medium)).foregroundStyle(C.ink2)
                    HStack(spacing: 6) {
                        OrvexSymbol(size: 12, color: C.mute)
                        Text("ORVEX · POWERING POSSIBILITIES").font(.num(9.5, .medium)).foregroundStyle(C.mute).environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(.top, 40).padding(.bottom, 24)
            }
            .frame(maxWidth: 460).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(C.bg.ignoresSafeArea())
        .onSubmit { if focus == 0 { focus = 1 } else { Task { await login() } } }
    }

    func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool, tag: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(C.mute).frame(width: 20)
            Group {
                if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text) }
            }
            .font(.ox(16)).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focus, equals: tag)
            .submitLabel(tag == 0 ? .next : .go)
            if tag == 1 {
                Button { showPass.toggle() } label: { Image(systemName: showPass ? "eye.slash" : "eye").foregroundStyle(C.mute) }
                    .accessibilityLabel(showPass ? "إخفاء كلمة المرور" : "إظهار كلمة المرور")
            }
        }
        .padding(.horizontal, 14).frame(height: 54)
        .background(C.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func login() async {
        guard !username.isEmpty, !password.isEmpty else { return }
        error = nil
        do { try await session.login(username: username.trimmingCharacters(in: .whitespaces).lowercased(), password: password) }
        catch { self.error = (error as? APIError)?.message ?? error.localizedDescription; Haptics.notify(.error) }
    }
}
