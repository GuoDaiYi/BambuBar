import SwiftUI
import AppKit

// MARK: - Dashboard

/// Compact landscape dashboard: progress, temperatures and controls.
/// Camera, AMS and the secondary status panel are intentionally not present.
struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var service: PrinterService

    @Environment(\.openWindow) private var openWindow
    @State private var showStopConfirm = false
    @State private var showTemperatureSheet = false

    private var status: PrinterStatus { service.status }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().overlay(Color.white.opacity(0.06))

            VStack(spacing: 9) {
                heroCard
                temperatureGrid
                controlCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 590, height: service.controlWarning == nil ? 450 : 470)
        .background(PanelBackground())
        .alert(Lang.t("取消当前打印？", "Cancel this print?"), isPresented: $showStopConfirm) {
            Button(Lang.t("取消打印", "Cancel print"), role: .destructive) { service.stopPrint() }
            Button(Lang.t("继续打印", "Keep printing"), role: .cancel) {}
        } message: {
            Text(Lang.t("打印任务会被立即中止，已打印的部分无法恢复。",
                        "The print will stop immediately. Printed material cannot be recovered."))
        }
        .sheet(isPresented: $showTemperatureSheet) {
            TemperatureSheet(service: service)
        }
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

            Spacer(minLength: 8)

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
                    Button(Lang.t("设置…", "Settings…")) { openWindow(id: "settings") }
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
                openWindow(id: "settings")
            }
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
                    size: 92
                )
                VStack(spacing: 1) {
                    if service.isOnline, status.state.isBusy || status.state == .finished {
                        Text("\(status.progress)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Image(systemName: service.isOnline ? status.state.symbol : "wifi.slash")
                            .font(.system(size: 24, weight: .medium))
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

    private var temperatureGrid: some View {
        HStack(spacing: 8) {
            TempTile(
                icon: .flame,
                title: Lang.t("喷嘴", "Nozzle"),
                current: status.nozzleTemp,
                target: status.nozzleTarget,
                tint: Theme.orange,
                enabled: service.isOnline
            ) { showTemperatureSheet = true }

            TempTile(
                icon: .bed,
                title: Lang.t("热床", "Bed"),
                current: status.bedTemp,
                target: status.bedTarget,
                tint: Theme.red.opacity(0.9),
                enabled: service.isOnline
            ) { showTemperatureSheet = true }

            TempTile(
                icon: .wind,
                title: Lang.t("风扇", "Fan"),
                current: Double(status.coolingFan),
                target: 0,
                tint: Theme.cyan,
                unit: "%",
                enabled: service.isOnline,
                targetText: Lang.t("占空比 \(status.coolingFan)%", "Duty \(status.coolingFan)%")
            ) { showTemperatureSheet = true }
        }
    }

    // MARK: Controls

    private var controlCard: some View {
        VStack(spacing: 8) {
            HStack {
                SectionHeader(
                    title: Lang.t("打印速度", "Print speed"),
                    icon: .gauge,
                    trailing: status.speedMagnitude > 0 ? "\(status.speedMagnitude)%" : nil
                )
            }
            SpeedSelector(
                level: status.speedLevel,
                enabled: service.isOnline && status.state.isBusy && !service.controlBlocked
            ) { level in
                service.setSpeed(level)
            }

            if let warning = service.controlWarning {
                HStack(alignment: .top, spacing: 6) {
                    TBIconView(icon: .shieldLock, size: 11, color: Theme.orange)
                    Text(warning)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(warning)
                }
                .foregroundStyle(Theme.orange)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(Lang.t("重试", "Retry")) {
                    service.clearControlBlock()
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.orange)
            }

            actionRow
        }
        .card(padding: 10, radius: 16)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                if status.state.canResume {
                    service.resume()
                } else {
                    service.pause()
                }
            } label: {
                HStack(spacing: 7) {
                    TBIconView(icon: status.state.canResume ? .play : .pause,
                               size: 12, color: canPauseResume ? Color(red: 0.02, green: 0.10, blue: 0.06) : Theme.textTertiary)
                    Text(status.state.canResume ? Lang.t("继续打印", "Resume print") : Lang.t("暂停打印", "Pause print"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(canPauseResume ? Color(red: 0.02, green: 0.10, blue: 0.06) : Theme.textTertiary)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(canPauseResume ? Theme.green : Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPauseResume)

            Button {
                showStopConfirm = true
            } label: {
                TBIconView(icon: .stop, size: 13, color: canStop ? Theme.red : Theme.textTertiary)
                    .frame(width: 40, height: 34)
                    .contentShape(Rectangle())
                    .foregroundStyle(canStop ? Theme.red : Theme.textTertiary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.red.opacity(canStop ? 0.13 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.red.opacity(canStop ? 0.22 : 0.06), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canStop)

            RoundIconButton(icon: .refresh, size: 34) {
                service.refresh()
            }
        }
    }

    private var canPauseResume: Bool {
        service.isOnline && (status.state.canPause || status.state.canResume) && !service.controlBlocked
    }

    private var canStop: Bool {
        status.state.isBusy && !service.controlBlocked
    }
}
