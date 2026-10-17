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
        .frame(width: 380)
        .environment(\.colorScheme, .dark)
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
            Text(app.authMessage ?? "正在连接拓竹云端…")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 420)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                LogoMark(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BambuBar")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("拓竹打印机 · 菜单栏控制台")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.bottom, 18)

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
                .padding(.top, 12)
            }

            Spacer(minLength: 14)

            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                Text("登录凭证仅保存在本机钥匙串，不会上传")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(20)
        .frame(width: 380, height: 486)
        .background(PanelBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            if account.isEmpty { focusedField = .account } else { focusedField = .password }
        }
    }

    // MARK: Forms

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("账号区域")
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
                            .frame(height: 28)
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

            fieldLabel("邮箱 / 手机号")
            inputField {
                TextField("拓竹账号", text: $account)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .account)
                    .onSubmit { focusedField = .password }
            }

            fieldLabel("密码")
            inputField {
                SecureField("账号密码", text: $password)
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
                    Text(app.isWorking ? "登录中…" : "登录拓竹账号")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.green)
                        .shadow(color: Theme.green.opacity(0.25), radius: 8, y: 3)
                )
            }
            .buttonStyle(.plain)
            .disabled(app.isWorking)
            .opacity(app.isWorking ? 0.8 : 1)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                feature("bolt.fill", "云端实时状态，进度与温度持续刷新")
                feature("slider.horizontal.3", "暂停 / 继续、四档调速、取消任务")
                feature("camera.fill", "AMS 耗材与局域网摄像头画面")
            }
            .padding(.top, 10)
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.green)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var codeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("需要邮箱验证码")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(account.isEmpty ? "验证码已发送到你的邮箱" : "已发送至 \(account)")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            fieldLabel("6 位验证码")
            inputField {
                TextField("000000", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(6)
                    .focused($focusedField, equals: .code)
                    .onSubmit { performCodeLogin() }
                    .onChange(of: code) { value in
                        let filtered = value.filter(\.isNumber)
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
                    Text(app.isWorking ? "验证中…" : "验证并登录")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.02, green: 0.10, blue: 0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.green)
                )
            }
            .buttonStyle(.plain)
            .disabled(app.isWorking)

            Button("返回，重新输入账号密码") {
                code = ""
                app.backToLogin()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
        }
        .onAppear { focusedField = .code }
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
            .frame(height: 36)
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
            Text("没有找到打印机")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(app.authMessage ?? "请先在 Bambu Handy 或 BambuStudio 中绑定打印机，然后再刷新。")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            HStack(spacing: 8) {
                Button {
                    app.refreshDevices()
                } label: {
                    Text("重新读取")
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
                    Text("设置")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)

            Button("退出当前账号") { app.logout() }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .background(PanelBackground())
    }
}
