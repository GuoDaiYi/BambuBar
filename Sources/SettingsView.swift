import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 12) {
                    accountCard
                    languageSection
                    generalSection
                }
                .frame(width: 294)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        printerSection
                        aboutSection
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 720, height: 480)
        .background(PanelBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.green)
            Text(Lang.t("设置", "Settings"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }

    // MARK: Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: Lang.t("拓竹账号", "Bambu Lab account"), icon: "person.crop.circle")
            HStack(spacing: 10) {
                LogoMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.session?.account ?? Lang.t("未登录", "Not signed in"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(app.session?.region.title ?? "—") · UID \(app.session?.uid ?? "—")")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Button(Lang.t("退出登录", "Sign out")) { app.logout() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.red.opacity(0.10)))
            }
        }
        .card(padding: 12, radius: 14)
    }

    // MARK: Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: Lang.t("语言", "Language"), icon: "globe")
            HStack(spacing: 2) {
                ForEach(AppLanguage.allCases) { language in
                    let selected = app.language == language
                    Button {
                        app.setLanguage(language)
                    } label: {
                        Text(language.title)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected ? Theme.green : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
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
        }
        .card(padding: 12, radius: 14)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.1.0"
    }

    // MARK: Printers

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: Lang.t("打印机", "Printers"), icon: "printer.fill")
                Button {
                    app.refreshDevices()
                } label: {
                    Label(Lang.t("刷新", "Refresh"), systemImage: "arrow.clockwise")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if app.devices.isEmpty {
                Text(Lang.t("暂未读取到设备", "No devices loaded"))
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 6)
            } else {
                ForEach(app.orderedDevices) { device in
                    deviceCard(device)
                }
            }
        }
    }

    private func deviceCard(_ device: CloudDevice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(device.online ? Theme.green : Color.white.opacity(0.3))
                    .frame(width: 5, height: 5)
                Text(device.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(device.model)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                if app.selectedID == device.serial {
                    Text(Lang.t("菜单栏", "Menu bar"))
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.green.opacity(0.12)))
                }
                Button {
                    app.selectedID = device.serial
                } label: {
                    Text(Lang.t("显示", "Show"))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(app.selectedID == device.serial ? Theme.textTertiary : Theme.cyan)
                }
                .buttonStyle(.plain)
                .disabled(app.selectedID == device.serial)
            }

            HStack(spacing: 6) {
                Text("SN \(device.serial)")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                Text("·")
                    .foregroundStyle(Theme.textTertiary)
                Text(Lang.t("访问码 \(masked(device.accessCode))", "Access code \(masked(device.accessCode))"))
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 7) {
                Image(systemName: "network")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                TextField(Lang.t("局域网 IP（摄像头用）", "LAN IP (camera)"), text: Binding(
                    get: { app.manualIPs[device.serial] ?? "" },
                    set: { app.setManualIP($0, for: device.serial) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )
                if let ip = app.services[device.serial]?.status.ipAddress, !ip.isEmpty {
                    Button {
                        app.setManualIP(ip, for: device.serial)
                    } label: {
                        Text(Lang.t("使用 \(ip)", "Use \(ip)"))
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: Lang.t("通用", "General"), icon: "slider.horizontal.3")
            VStack(spacing: 0) {
                toggleRow(
                    icon: "bell.badge.fill",
                    title: Lang.t("打印完成 / 异常通知", "Print finished / error notifications"),
                    subtitle: Lang.t("任务结束时发送 macOS 通知", "Send a macOS notification when a job ends"),
                    isOn: $app.notificationsEnabled
                )
                Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 30)
                toggleRow(
                    icon: "power",
                    title: Lang.t("开机自动启动", "Launch at login"),
                    subtitle: Lang.t("登录 macOS 后在菜单栏运行", "Start in the menu bar after you sign in"),
                    isOn: Binding(
                        get: { app.launchAtLogin },
                        set: { app.updateLaunchAtLogin($0) }
                    )
                )
            }
            .padding(.horizontal, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 9)
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: Lang.t("关于", "About"), icon: "info.circle")
            HStack(spacing: 8) {
                Text("BambuBar \(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("·")
                    .foregroundStyle(Theme.textTertiary)
                Text(Lang.t("云端状态 1 秒刷新", "Live cloud status, ~1s refresh"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button(Lang.t("打开日志", "Open log")) {
                    NSWorkspace.shared.selectFile(Log.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                Button(Lang.t("退出 App", "Quit")) { app.quit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.red)
            }
            Text(Lang.t("摄像头通过打印机局域网 6000 端口直连；填写 IP 后才会显示摄像头。远程网络下云端画面使用私有协议，暂不支持。",
                        "The camera connects directly to the printer on port 6000 and only appears after you enter a LAN IP. Cloud camera streaming uses a proprietary protocol and is not supported."))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private func masked(_ code: String) -> String {
        guard code.count > 4 else { return String(repeating: "•", count: max(code.count, 4)) }
        return String(repeating: "•", count: code.count - 4) + code.suffix(4)
    }
}
