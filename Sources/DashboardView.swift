import SwiftUI
import AppKit

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var service: PrinterService

    @Environment(\.openWindow) private var openWindow
    @State private var showStopConfirm = false
    @State private var showTemperatureSheet = false
    @State private var showCameraSheet = false

    private var status: PrinterStatus { service.status }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider().overlay(Color.white.opacity(0.06))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 11) {
                    heroCard
                    temperatureGrid
                    speedCard
                    actionRow
                    amsSection
                    cameraSection
                    footer
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 380, height: 624)
        .background(PanelBackground())
        .alert("取消当前打印？", isPresented: $showStopConfirm) {
            Button("取消打印", role: .destructive) { service.stopPrint() }
            Button("继续打印", role: .cancel) {}
        } message: {
            Text("打印任务会被立即中止，已打印的部分无法恢复。")
        }
        .sheet(isPresented: $showTemperatureSheet) {
            TemperatureSheet(service: service)
        }
        .sheet(isPresented: $showCameraSheet) {
            CameraSheet(
                name: service.device.name,
                host: app.cameraHost(for: service) ?? "",
                accessCode: service.device.accessCode
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.green.opacity(0.13))
                Image(systemName: "printer.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(service.device.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Circle()
                        .fill(service.isOnline ? Theme.green : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
                Text("\(service.device.model) · \(service.isOnline ? status.stageText : "离线")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

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
                    Button("刷新设备列表") { app.refreshDevices() }
                    Button("设置…") { openWindow(id: "settings") }
                    Divider()
                    Button("退出 BambuBar") { app.quit() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("切换")
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

            RoundIconButton(icon: "gearshape.fill", size: 28) {
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
                    size: 88
                )
                VStack(spacing: 1) {
                    if service.isOnline, status.state.isBusy || status.state == .finished {
                        Text("\(status.progress)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Image(systemName: service.isOnline ? status.state.symbol : "wifi.slash")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(service.isOnline ? status.state.tint : Color.white.opacity(0.35))
                        Text(service.isOnline ? status.state.shortLabel : "离线")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    StateBadge(state: status.state, online: service.isOnline)
                    if status.state == .running, let eta = status.etaText {
                        Text("预计 \(eta)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }

                Text(service.isOnline ? status.displayName : "打印机离线")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    InfoChip(icon: "square.stack.3d.up.fill", text: status.layerText)
                    InfoChip(icon: "clock.fill", text: status.remainingText)
                }

                if status.speedLevel > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(status.speedLabel) · \(status.speedMagnitude)%")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.048))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
        )
    }

    // MARK: Temperatures

    private var temperatureGrid: some View {
        HStack(spacing: 7) {
            TempTile(
                icon: "flame.fill",
                title: "喷嘴",
                current: status.nozzleTemp,
                target: status.nozzleTarget,
                tint: Theme.orange,
                enabled: service.isOnline
            ) { showTemperatureSheet = true }

            TempTile(
                icon: "rectangle.compress.vertical",
                title: "热床",
                current: status.bedTemp,
                target: status.bedTarget,
                tint: Theme.red.opacity(0.9),
                enabled: service.isOnline
            ) { showTemperatureSheet = true }

            TempTile(
                icon: "wind",
                title: "风扇",
                current: Double(status.coolingFan),
                target: 0,
                tint: Theme.cyan,
                unit: "%",
                enabled: service.isOnline,
                targetText: "占空比 \(status.coolingFan)%"
            ) { showTemperatureSheet = true }
        }
    }

    // MARK: Speed

    private var speedCard: some View {
        VStack(spacing: 7) {
            SectionHeader(title: "打印速度", icon: "speedometer", trailing: status.speedMagnitude > 0 ? "\(status.speedMagnitude)%" : nil)
            SpeedSelector(level: status.speedLevel, enabled: service.isOnline && status.state.isBusy) { level in
                service.setSpeed(level)
            }
        }
        .card(padding: 10, radius: 14)
    }

    // MARK: Actions

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
                    Image(systemName: status.state.canResume ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(status.state.canResume ? "继续打印" : "暂停打印")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(canPauseResume ? Color(red: 0.02, green: 0.10, blue: 0.06) : Theme.textTertiary)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(canPauseResume ? Theme.green : Color.white.opacity(0.06))
                        .shadow(color: canPauseResume ? Theme.green.opacity(0.25) : .clear, radius: 6)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPauseResume)

            Button {
                showStopConfirm = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 40, height: 36)
                    .foregroundStyle(status.state.isBusy ? Theme.red : Theme.textTertiary)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.red.opacity(status.state.isBusy ? 0.13 : 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(Theme.red.opacity(status.state.isBusy ? 0.22 : 0.06), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!status.state.isBusy)

            RoundIconButton(icon: "arrow.clockwise", size: 36) {
                service.refresh()
                app.refreshDevices()
            }
        }
    }

    private var canPauseResume: Bool {
        service.isOnline && (status.state.canPause || status.state.canResume)
    }

    // MARK: Camera

    @ViewBuilder
    private var cameraSection: some View {
        if status.cameraAvailable {
            VStack(spacing: 8) {
                SectionHeader(title: "实时画面", icon: "video.fill", trailing: "局域网")
                if let host = app.cameraHost(for: service), !host.isEmpty {
                    CameraPreview(host: host, accessCode: service.device.accessCode) {
                        showCameraSheet = true
                    }
                } else {
                    cameraHint(
                        icon: "network",
                        title: "需要填写打印机 IP",
                        subtitle: "在设置中填写局域网 IP 后即可查看画面"
                    )
                }
            }
            .card(padding: 10, radius: 14)
        } else if service.device.model.lowercased().contains("mini") {
            HStack(spacing: 8) {
                Image(systemName: "video.slash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("此机型没有内置摄像头")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Text("A1 mini 未配备腔体摄像头")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .card(padding: 11, radius: 14)
        }
    }

    private func cameraHint(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.05)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: AMS

    @ViewBuilder
    private var amsSection: some View {
        if status.hasAMS {
            VStack(spacing: 7) {
                SectionHeader(
                    title: "AMS 耗材",
                    icon: "circle.grid.2x2.fill",
                    trailing: amsTrailing
                )
                HStack(spacing: 2) {
                    if status.amsTrays.isEmpty, let external = status.externalTray {
                        SpoolView(tray: external)
                    } else {
                        ForEach(displayTrays) { tray in
                            SpoolView(tray: tray)
                        }
                        if let external = status.externalTray, !external.isEmpty {
                            SpoolView(tray: external)
                        }
                    }
                }
            }
            .card(padding: 10, radius: 14)
        }
    }

    private var amsTrailing: String? {
        var parts: [String] = []
        if let h = status.amsHumidity { parts.append("湿度 \(h)%") }
        if let t = status.amsTemp { parts.append("\(Int(t.rounded()))°C") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var displayTrays: [AMSTray] {
        let existing = Dictionary(uniqueKeysWithValues: status.amsTrays.map { ($0.slot, $0) })
        return (0..<4).map { slot in
            existing[slot] ?? AMSTray(id: slot, slot: slot, type: "", colorHex: "30343CFF", remain: nil)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(app.cloudConnected ? Theme.green : Theme.orange)
                .frame(width: 5, height: 5)
            Text(app.cloudConnected ? "云端已连接" : "云端重连中")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            if let updated = status.lastUpdate {
                Text("·")
                    .foregroundStyle(Theme.textTertiary)
                Text("更新于 \(timeString(updated))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if let err = app.authMessage, !err.isEmpty {
                Text(err)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.orange)
                    .lineLimit(1)
            }
        }
        .padding(.top, 1)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - Camera preview

struct CameraPreview: View {
    let host: String
    let accessCode: String
    var onExpand: () -> Void = {}

    @StateObject private var camera = CameraClient()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.45))

            if let image = camera.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 7) {
                    if camera.connected {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "video.slash")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Text(camera.errorText ?? "正在连接摄像头…")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            VStack {
                HStack {
                    if camera.connected {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.red).frame(width: 4, height: 4)
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .tracking(0.6)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 23, height: 23)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            camera.start(host: host, accessCode: accessCode)
        }
        .onDisappear {
            camera.stop()
        }
    }
}

struct CameraSheet: View {
    let name: String
    let host: String
    let accessCode: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraClient()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .foregroundStyle(Theme.green)
                Text("\(name) · 实时画面")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            ZStack {
                Color.black
                if let image = camera.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(camera.errorText ?? "正在连接摄像头…")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .frame(width: 720, height: 405)
        }
        .frame(width: 720, height: 455)
        .background(PanelBackground())
        .onAppear { camera.start(host: host, accessCode: accessCode) }
        .onDisappear { camera.stop() }
    }
}
