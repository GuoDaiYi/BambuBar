import SwiftUI
import AppKit

/// Read-only print progress monitor.
///
/// There are deliberately no pause, resume, cancel, speed or temperature
/// controls here. The panel shows progress, temperatures and timing only.
struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var service: PrinterService

    private var status: PrinterStatus { service.status }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 10)
                .padding(.vertical, 9)

            Divider().overlay(Color.white.opacity(0.06))

            VStack(spacing: 8) {
                heroCard
                temperatureGrid
                monitorStrip
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .frame(width: 560, height: 325, alignment: .top)
        .background(PanelBackground())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.green.opacity(0.13))
                TBIconView(icon: .printer, size: 15, color: Theme.green)
            }
            .frame(width: 31, height: 31)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(service.device.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Circle()
                        .fill(service.isOnline ? Theme.green : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
                Text("\(service.device.model) · \(service.isOnline ? status.stageText : Lang.t("离线", "Offline"))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let update = app.availableUpdate {
                Button {
                    app.openUpdate()
                } label: {
                    HStack(spacing: 4) {
                        TBIconView(icon: .download, size: 9, color: Theme.orange)
                        Text(update.version)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.orange.opacity(0.12)))
                    .overlay(Capsule().stroke(Theme.orange.opacity(0.24), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(Lang.t("有新版本可用，点击前往下载", "A new version is available. Click to download."))
            }

            LanguageToggle(compact: true)

            if app.orderedServices.count > 1 {
                Menu {
                    ForEach(app.orderedServices) { item in
                        Button {
                            app.selectedID = item.id
                        } label: {
                            if item.id == service.id {
                                Label("\(item.device.name) · \(item.status.state.shortLabel)", systemImage: "checkmark")
                            } else {
                                Text("\(item.device.name) · \(item.status.state.shortLabel)")
                            }
                        }
                    }
                    Divider()
                    Button(Lang.t("刷新设备列表", "Refresh printers")) { app.refreshDevices() }
                    Divider()
                    Button(Lang.t("退出 BambuBar", "Quit BambuBar")) { app.quit() }
                } label: {
                    HStack(spacing: 4) {
                        TBIconView(icon: .arrowsExchange, size: 10, color: Theme.textSecondary)
                        Text(Lang.t("切换", "Switch"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            RoundIconButton(icon: .settings, size: 28) {
                app.showSettings = true
            }
            .help(Lang.t("设置", "Settings"))

            RoundIconButton(icon: .power, tint: Theme.textSecondary, size: 28) {
                app.quit()
            }
            .help(Lang.t("退出 BambuBar", "Quit BambuBar"))
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                ProgressRing(
                    progress: status.state == .idle ? 0 : Double(status.progress) / 100,
                    tint: service.isOnline ? status.state.tint : Color.white.opacity(0.35),
                    lineWidth: 7,
                    size: 104
                )
                VStack(spacing: 1) {
                    if service.isOnline, status.state.isBusy || status.state == .finished {
                        Text("\(status.progress)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Image(systemName: service.isOnline ? status.state.symbol : "wifi.slash")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(service.isOnline ? status.state.tint : Color.white.opacity(0.35))
                        Text(service.isOnline ? status.state.shortLabel : Lang.t("离线", "Offline"))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    StateBadge(state: status.state, online: service.isOnline)
                    if status.state == .running, let eta = status.etaText {
                        Text(Lang.t("预计 \(eta)", "ETA \(eta)"))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                Text(service.isOnline ? status.displayName : Lang.t("打印机离线", "Printer offline"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    if status.state == .prepare, !status.phaseText.isEmpty {
                        InfoChip(icon: .download, text: status.phaseText)
                    }
                    InfoChip(icon: .stack, text: status.layerText)
                    InfoChip(icon: .clock, text: status.remainingText)
                    InfoChip(icon: .gauge, text: "\(status.speedLabel) · \(status.speedMagnitude)%")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.048))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (service.isOnline ? status.state.tint : Theme.cyan).opacity(0.16),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
        )
    }

    // MARK: Read-only temperatures

    private var temperatureGrid: some View {
        HStack(spacing: 8) {
            TempTile(
                icon: .flame,
                title: Lang.t("喷嘴", "Nozzle"),
                current: status.nozzleTemp,
                target: status.nozzleTarget,
                tint: Theme.orange
            )
            TempTile(
                icon: .bed,
                title: Lang.t("热床", "Bed"),
                current: status.bedTemp,
                target: status.bedTarget,
                tint: Theme.red.opacity(0.9)
            )
            TempTile(
                icon: .wind,
                title: Lang.t("风扇", "Fan"),
                current: Double(status.coolingFan),
                target: 0,
                tint: Theme.cyan,
                unit: "%",
                targetText: Lang.t("占空比 \(status.coolingFan)%", "Duty \(status.coolingFan)%")
            )
        }
    }

    // MARK: Monitor strip

    private var monitorStrip: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(app.cloudConnected ? Theme.green : Theme.orange)
                .frame(width: 5, height: 5)
            Text(app.cloudConnected ? Lang.t("云端已连接", "Cloud connected") : Lang.t("云端重连中", "Reconnecting"))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            if let updated = status.lastUpdate {
                Text("·").foregroundStyle(Theme.textTertiary)
                Text(Lang.t("更新于 \(timeString(updated))", "Updated \(timeString(updated))"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text("·").foregroundStyle(Theme.textTertiary)
            Text(Lang.t("只读监控", "Monitor only"))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            Button {
                service.refresh()
            } label: {
                HStack(spacing: 4) {
                    TBIconView(icon: .refresh, size: 9, color: Theme.textTertiary)
                    Text(Lang.t("刷新", "Refresh"))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}
