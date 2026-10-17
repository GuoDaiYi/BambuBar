import SwiftUI
import AppKit

/// Settings are part of the same menu-bar panel, not a separate window.
/// A back arrow returns to the read-only monitor.
struct SettingsView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 10)
                .padding(.vertical, 9)

            Divider().overlay(Color.white.opacity(0.06))

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 9) {
                    accountCard
                    languageSection
                }
                .frame(width: 258)

                VStack(spacing: 9) {
                    generalSection
                    aboutSection
                }
                .frame(width: 256)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 560, height: 300, alignment: .top)
        .background(PanelBackground())
        .environment(\.colorScheme, .dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                app.showSettings = false
            } label: {
                HStack(spacing: 4) {
                    TBIconView(icon: .arrowLeft, size: 12, color: Theme.textSecondary)
                    Text(Lang.t("返回", "Back"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            TBIconView(icon: .settings, size: 12, color: Theme.green)
            Text(Lang.t("设置", "Settings"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()

            Button {
                app.quit()
            } label: {
                HStack(spacing: 4) {
                    TBIconView(icon: .power, size: 10, color: Theme.red)
                    Text(Lang.t("退出", "Quit"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.red)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: Lang.t("拓竹账号", "Bambu Lab account"), icon: .user)
            HStack(spacing: 9) {
                LogoMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.session?.account ?? Lang.t("未登录", "Not signed in"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(app.session?.region.title ?? "—") · UID \(app.session?.uid ?? "—")")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    app.logout()
                } label: {
                    TBIconView(icon: .logout, size: 11, color: Theme.red)
                        .frame(width: 26, height: 24)
                        .contentShape(Rectangle())
                        .background(Capsule().fill(Theme.red.opacity(0.10)))
                }
                .buttonStyle(.plain)
                .help(Lang.t("退出登录", "Sign out"))
            }
        }
        .card(padding: 11, radius: 16)
    }

    // MARK: Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: Lang.t("语言", "Language"), icon: .language)
            LanguageToggle()
        }
        .card(padding: 11, radius: 16)
    }

    // MARK: General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: Lang.t("通用", "General"), icon: .settings)
            VStack(spacing: 0) {
                toggleRow(
                    icon: .bell,
                    title: Lang.t("打印完成 / 异常通知", "Print notifications"),
                    subtitle: Lang.t("任务结束时发送通知", "Notify when a job ends"),
                    isOn: $app.notificationsEnabled
                )
                Divider().overlay(Color.white.opacity(0.05)).padding(.leading, 28)
                toggleRow(
                    icon: .power,
                    title: Lang.t("开机自动启动", "Launch at login"),
                    subtitle: Lang.t("登录后在菜单栏运行", "Run in the menu bar after sign-in"),
                    isOn: Binding(
                        get: { app.launchAtLogin },
                        set: { app.updateLaunchAtLogin($0) }
                    )
                )
            }
            .padding(.horizontal, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .card(padding: 11, radius: 16)
    }

    private func toggleRow(icon: TBIcon, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            TBIconView(icon: icon, size: 10, color: Theme.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader(title: Lang.t("关于", "About"), icon: .infoCircle)
            HStack(spacing: 6) {
                Text("BambuBar \(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("·").foregroundStyle(Theme.textTertiary)
                Text(Lang.t("只读进度监控", "Read-only monitor"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            HStack(spacing: 10) {
                Button(app.availableUpdate == nil
                       ? Lang.t("检查更新", "Check updates")
                       : Lang.t("下载 \(app.availableUpdate?.version ?? "")", "Download \(app.availableUpdate?.version ?? "")")) {
                    if app.availableUpdate != nil {
                        app.openUpdate()
                    } else {
                        app.checkForUpdates(force: true)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(app.availableUpdate == nil ? Theme.textTertiary : Theme.green)

                Button(Lang.t("打开日志", "Open log")) {
                    NSWorkspace.shared.selectFile(Log.path, inFileViewerRootedAtPath: "")
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

                Spacer()

                Button(Lang.t("退出 App", "Quit")) { app.quit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.red)
            }
        }
        .card(padding: 11, radius: 16)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.1"
    }
}
