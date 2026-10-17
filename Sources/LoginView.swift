import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        Group {
            switch app.authStep {
            case .loading:
                LoadingView()
            case .login, .code:
                LoginView()
            case .empty:
                NoDevicesView()
            case .ready:
                if let service = app.selectedService {
                    DashboardView(service: service)
                        .id(service.id)
                } else {
                    LoadingView()
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .modifier(PopoverEntrance())
    }
}

// MARK: - Loading

struct LoadingView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 16) {
            LogoMark(size: 52)
            Text("BambuBar")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            ProgressView()
                .controlSize(.small)
            Text(app.authMessage ?? Lang.t("正在连接拓竹云端…", "Connecting to Bambu Cloud…"))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 620, height: 360)
        .background(PanelBackground())
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject private var app: AppModel
    @AppStorage("loginAccount") private var account: String = ""
    @State private var password: String = ""
    @State private var code: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case account, password, code }

    var body: some View {
        HStack(spacing: 0) {
            brandingPanel
                .frame(width: 238)
            Divider().overlay(Color.white.opacity(0.07))
            formPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 400)
        .background(PanelBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            if account.isEmpty { focusedField = .account } else { focusedField = .password }
        }
    }

    // MARK: Left branding

    private var brandingPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark(size: 54)
            Text("BambuBar")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 14)
            Text(Lang.t("拓竹打印机 · 菜单栏控制台", "Bambu Lab printers · menu bar console"))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 10) {
                feature("bolt.fill", Lang.t("云端实时状态，进度与温度持续刷新",
                                            "Live cloud status with progress and temperatures"))
                feature("slider.horizontal.3", Lang.t("暂停 / 继续、四档调速、取消任务",
                                                     "Pause, resume, four speed modes and cancel"))
                feature("bell.badge.fill", Lang.t("打印完成与异常通知",
                                                  "Print finished and error notifications"))
                feature("globe", Lang.t("中文 / English 随时切换",
                                        "Switch between English and Chinese"))
            }
            .padding(.top, 26)

            Spacer(minLength: 16)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                Text(Lang.t("登录凭证仅保存在本机钥匙串，不会上传",
                            "Credentials stay in the macOS Keychain and never leave this Mac."))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.green)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Right form

    private var formPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(app.authStep == .code
                     ? Lang.t("输入验证码", "Enter verification code")
                     : Lang.t("登录拓竹账号", "Sign in"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                languageMenu
            }
            .padding(.bottom, 16)

            if app.authStep == .code {
                codeForm
            } else {
                loginForm
            }

            if let message = app.authMessage, !message.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.orange)
                    Text(message)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 10)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 11) {
            fieldLabel(Lang.t("账号区域", "REGION"))
            HStack(spacing: 2) {
                ForEach(CloudRegion.allCases) { region in
                    let selected = app.loginRegion == region
                    Button {
                        app.loginRegion = region
                    } label: {
                        Text(region.title)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected ? Theme.green : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 27)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selected ? Theme.green.opacity(0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )

            fieldLabel(Lang.t("邮箱 / 手机号", "EMAIL / PHONE"))
            inputField {
                TextField(Lang.t("邮箱或手机号", "Email or phone"), text: $account)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .account)
                    .onSubmit { focusedField = .password }
            }

            fieldLabel(Lang.t("密码", "PASSWORD"))
            inputField {
                SecureField(Lang.t("账号密码", "Password"), text: $password)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .password)
                    .onSubmit { performLogin() }
            }

            Button(action: performLogin) {
                HStack(spacing: 7) {
                    if app.isWorking {
                        ProgressView().controlSize(.small).tint(.black)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(app.isWorking ? Lang.t("登录中…", "Signing in…") : Lang.t("登录拓竹账号", "Sign in to Bambu Lab"))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.green)
                        .shadow(color: Theme.green.opacity(0.25), radius: 8, y: 3)
                )
            }
            .buttonStyle(.plain)
            .disabled(app.isWorking)
            .opacity(app.isWorking ? 0.8 : 1)
            .padding(.top, 3)

            HStack(spacing: 5) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 9, weight: .semibold))
                Text(Lang.t("支持邮箱或手机短信验证码登录", "Email or SMS verification code supported"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Theme.textTertiary)
        }
    }

    private var codeForm: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Lang.t("需要邮箱或短信验证码", "Verification required"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(account.isEmpty
                         ? Lang.t("验证码已发送到你的邮箱或手机", "A code was sent to your email or phone")
                         : Lang.t("已发送至 \(account)", "Sent to \(account)"))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            fieldLabel(Lang.t("6 位验证码", "6-DIGIT CODE"))
            inputField {
                TextField("000000", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(6)
                    .focused($focusedField, equals: .code)
                    .onSubmit { performCodeLogin() }
                    .onChange(of: code) { value in
                        let filtered = value.filter { $0.isNumber }
                        if filtered != value { code = String(filtered.prefix(8)) }
                    }
            }

            Button(action: performCodeLogin) {
                HStack(spacing: 7) {
                    if app.isWorking {
                        ProgressView().controlSize(.small).tint(.black)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(app.isWorking ? Lang.t("验证中…", "Verifying…") : Lang.t("验证并登录", "Verify and sign in"))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.green)
                )
            }
            .buttonStyle(.plain)
            .disabled(app.isWorking)

            Button(Lang.t("返回，重新输入账号密码", "Back to sign in")) {
                code = ""
                app.backToLogin()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textSecondary)

            Text(Lang.t("验证码会发送到账号绑定的邮箱或手机；没收到可以返回重新登录。",
                        "The code is sent to the email or phone linked to your account. Go back to sign in to request another."))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { focusedField = .code }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    app.setLanguage(language)
                } label: {
                    if app.language == language {
                        Label(language.title, systemImage: "checkmark")
                    } else {
                        Text(language.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 9, weight: .semibold))
                Text(app.language.shortTitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 1)
    }

    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 11)
            .frame(height: 35)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    private func performLogin() {
        focusedField = nil
        app.login(account: account, password: password)
    }

    private func performCodeLogin() {
        focusedField = nil
        app.submitCode(code)
    }
}

// MARK: - No devices

struct NoDevicesView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            LogoMark(size: 50)
            Text(Lang.t("没有找到打印机", "No printers found"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(app.authMessage ?? Lang.t("请先在 Bambu Handy 或 BambuStudio 中绑定打印机，然后再刷新。",
                                          "Bind a printer in Bambu Handy or Bambu Studio, then refresh."))
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 8) {
                Button {
                    app.refreshDevices()
                } label: {
                    Text(Lang.t("重新读取", "Retry"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(Capsule().fill(Theme.green))
                }
                .buttonStyle(.plain)

                Button {
                    openWindow(id: "settings")
                } label: {
                    Text(Lang.t("设置", "Settings"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)

            Button(Lang.t("退出当前账号", "Sign out")) { app.logout() }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 620, height: 360)
        .background(PanelBackground())
    }
}
