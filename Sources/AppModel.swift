import Foundation
import SwiftUI
import AppKit
import Combine
import UserNotifications
import ServiceManagement

enum AuthStep: Equatable {
    case loading
    case login
    case code
    case empty
    case ready
}

@MainActor
final class AppModel: ObservableObject {
    @Published var session: CloudSession?
    @Published var devices: [CloudDevice] = []
    @Published var services: [String: PrinterService] = [:]
    @Published var selectedID: String {
        didSet {
            if !selectedID.isEmpty {
                UserDefaults.standard.set(selectedID, forKey: Keys.selected)
            }
        }
    }
    @Published var authStep: AuthStep = .loading
    @Published var authMessage: String?
    @Published var isWorking = false
    @Published var cloudConnected = false
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
            if notificationsEnabled { NotificationManager.shared.request() }
        }
    }
    @Published var launchAtLogin: Bool = false
    @Published var manualIPs: [String: String] = [:] {
        didSet { persistManualIPs() }
    }
    @Published var loginRegion: CloudRegion {
        didSet { UserDefaults.standard.set(loginRegion.rawValue, forKey: Keys.region) }
    }
    @Published var lastRefresh: Date?

    private let api = CloudAPI()
    private let cloud = BambuCloud()
    private var pendingAccount = ""
    private var ticker: Timer?
    private var bootstrapped = false
    private var serviceObservers: [String: AnyCancellable] = [:]

    private enum Keys {
        static let selected = "selectedPrinter"
        static let notifications = "notificationsEnabled"
        static let region = "loginRegion"
        static let account = "loginAccount"
        static let manualIPs = "manualIPs"
    }

    init(startNetwork: Bool = true) {
        selectedID = UserDefaults.standard.string(forKey: Keys.selected) ?? ""
        notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notifications) as? Bool ?? true
        let regionRaw = UserDefaults.standard.string(forKey: Keys.region) ?? CloudRegion.china.rawValue
        loginRegion = CloudRegion(rawValue: regionRaw) ?? .china
        pendingAccount = UserDefaults.standard.string(forKey: Keys.account) ?? ""
        if let data = UserDefaults.standard.data(forKey: Keys.manualIPs),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            manualIPs = decoded
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        guard startNetwork else {
            authStep = .login
            return
        }
        session = SessionStore.load()
        wireCloud()
        startTicker()
        Task { await bootstrap() }
    }

    static func demo() -> AppModel {
        let app = AppModel(startNetwork: false)
        let mainDevice = CloudDevice(
            serial: "01S00A000000001",
            name: "A1 · 工作台",
            model: "A1",
            accessCode: "12345678",
            online: true
        )
        let mini = CloudDevice(
            serial: "01S00A000000002",
            name: "A1 mini",
            model: "A1 mini",
            accessCode: "87654321",
            online: true
        )
        var s = PrinterStatus()
        s.state = .running
        s.gcodeStateRaw = "RUNNING"
        s.progress = 63
        s.remainingMinutes = 78
        s.layer = 118
        s.totalLayers = 186
        s.speedLevel = 3
        s.speedMagnitude = 124
        s.nozzleTemp = 219.4
        s.nozzleTarget = 220
        s.bedTemp = 59.8
        s.bedTarget = 60
        s.chamberTemp = 31.6
        s.coolingFan = 88
        s.jobName = "Cyber Dragon · 分件套"
        s.gcodeFile = "cyber_dragon_plate_2.gcode.3mf"
        s.wifiSignal = -48
        s.cameraAvailable = true
        s.ipAddress = "192.168.31.88"
        s.amsHumidity = 32
        s.amsTemp = 27.6
        s.activeTray = 0
        s.printError = 0
        s.stage = 0
        s.lastUpdate = Date()
        s.amsTrays = [
            AMSTray(id: 0, slot: 0, type: "PLA", colorHex: "22C55EFF", remain: 78, brand: "Bambu", isActive: true),
            AMSTray(id: 1, slot: 1, type: "PLA", colorHex: "F59E0BFF", remain: 54, brand: "Bambu"),
            AMSTray(id: 2, slot: 2, type: "PETG", colorHex: "38BDF8FF", remain: 31, brand: "Bambu"),
            AMSTray(id: 3, slot: 3, type: "PLA", colorHex: "F8FAFCFF", remain: 12, brand: "Bambu")
        ]

        var idle = PrinterStatus()
        idle.state = .idle
        idle.gcodeStateRaw = "IDLE"
        idle.nozzleTemp = 28.2
        idle.bedTemp = 25.4
        idle.coolingFan = 0
        idle.speedLevel = 2
        idle.lastUpdate = Date()

        let main = PrinterService(device: mainDevice)
        main.setDemoStatus(s)
        let second = PrinterService(device: mini)
        second.setDemoStatus(idle)

        app.session = CloudSession(
            accessToken: "demo",
            refreshToken: "demo",
            uid: "1000000000",
            region: .china,
            account: "demo@example.com",
            expiresAt: Date().addingTimeInterval(86400)
        )
        app.devices = [mainDevice, mini]
        app.services = [mainDevice.serial: main, mini.serial: second]
        app.serviceObservers = [:]
        app.selectedID = mainDevice.serial
        app.manualIPs = [mainDevice.serial: "192.168.31.88"]
        app.cloudConnected = true
        app.authStep = .ready
        app.isWorking = false
        return app
    }

    // MARK: - Derived

    var orderedDevices: [CloudDevice] {
        devices
    }

    var orderedServices: [PrinterService] {
        devices.compactMap { services[$0.serial] }
    }

    var selectedService: PrinterService? {
        if let s = services[selectedID] { return s }
        return orderedServices.first
    }

    var menuTitle: String {
        guard let service = selectedService else { return "BambuBar" }
        let status = service.status
        if authStep != .ready { return "BambuBar" }
        if !service.isOnline { return "离线" }
        switch status.state {
        case .running, .prepare: return "\(status.progress)%"
        case .paused: return "暂停"
        case .finished: return "完成"
        case .failed: return "异常"
        case .idle: return "待机"
        case .offline: return "离线"
        case .unknown: return "等待"
        }
    }

    func cameraHost(for service: PrinterService) -> String? {
        let manual = (manualIPs[service.device.serial] ?? "").trimmingCharacters(in: .whitespaces)
        if !manual.isEmpty { return manual }
        if let ip = service.status.ipAddress, !ip.isEmpty { return ip }
        return nil
    }

    // MARK: - Bootstrap / auth

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        guard let existing = session else {
            authStep = .login
            return
        }
        if existing.isExpired {
            SessionStore.clear()
            session = nil
            authStep = .login
            authMessage = "登录已过期，请重新登录"
            return
        }
        session = existing
        authStep = .loading
        let valid = await api.isSessionValid(existing)
        if !valid {
            SessionStore.clear()
            session = nil
            authStep = .login
            authMessage = "登录已过期，请重新登录"
            return
        }
        await loadDevices(startCloud: true)
    }

    func login(account: String, password: String) {
        guard !isWorking else { return }
        let account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !password.isEmpty else {
            authMessage = "请输入账号和密码"
            return
        }
        isWorking = true
        authMessage = nil
        pendingAccount = account
        UserDefaults.standard.set(account, forKey: Keys.account)

        Task {
            do {
                let outcome = try await api.login(account: account, password: password, region: loginRegion)
                switch outcome {
                case .loggedIn(let newSession):
                    completeLogin(newSession)
                case .needsCode:
                    isWorking = false
                    authStep = .code
                    authMessage = "验证码已发送到你的邮箱，请输入 6 位验证码"
                }
            } catch {
                isWorking = false
                authMessage = error.localizedDescription
            }
        }
    }

    func submitCode(_ code: String) {
        guard !isWorking else { return }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            authMessage = "请输入邮箱验证码"
            return
        }
        isWorking = true
        authMessage = nil
        Task {
            do {
                let newSession = try await api.loginWithCode(account: pendingAccount, code: code, region: loginRegion)
                completeLogin(newSession)
            } catch {
                isWorking = false
                authMessage = error.localizedDescription
            }
        }
    }

    func backToLogin() {
        authStep = .login
        authMessage = nil
    }

    private func completeLogin(_ newSession: CloudSession) {
        isWorking = false
        session = newSession
        SessionStore.save(newSession)
        authStep = .loading
        authMessage = nil
        wireCloud()
        Task { await loadDevices(startCloud: true) }
    }

    func logout() {
        cloud.stop()
        SessionStore.clear()
        session = nil
        devices = []
        services = [:]
        selectedID = ""
        cloudConnected = false
        authStep = .login
        authMessage = nil
    }

    func refreshDevices() {
        guard session != nil else { return }
        Task { await loadDevices(startCloud: true) }
    }

    private func loadDevices(startCloud: Bool) async {
        guard let session else { return }
        do {
            let fetched = try await api.fetchDevices(session: session)
            devices = fetched
            syncServices(with: fetched)
            lastRefresh = Date()
            if fetched.isEmpty {
                authStep = .empty
                authMessage = "这个账号下还没有绑定打印机"
                cloud.stop()
                cloudConnected = false
                return
            }
            authStep = .ready
            if selectedID.isEmpty || services[selectedID] == nil {
                if let first = fetched.first(where: { $0.online }) ?? fetched.first {
                    selectedID = first.serial
                }
            }
            if startCloud {
                let serials = fetched.map(\.serial)
                wireCloud()
                cloud.start(session: session, serials: serials)
            }
        } catch CloudError.unauthorized {
            logout()
            authMessage = "登录已过期，请重新登录"
        } catch {
            authStep = devices.isEmpty ? .empty : .ready
            authMessage = error.localizedDescription
            Log.write("loadDevices failed: \(error.localizedDescription)")
        }
    }

    private func syncServices(with devices: [CloudDevice]) {
        var next: [String: PrinterService] = [:]
        var observers: [String: AnyCancellable] = [:]
        for device in devices {
            if let existing = services[device.serial] {
                existing.updateDevice(device)
                next[device.serial] = existing
                if let observer = serviceObservers[device.serial] { observers[device.serial] = observer }
            } else {
                let service = PrinterService(device: device)
                service.sendHandler = { [weak self] serial, body in
                    self?.cloud.send(serial: serial, body: body)
                }
                service.onStateTransition = { [weak self] status, old, new in
                    self?.handleTransition(status: status, old: old, new: new, service: service)
                }
                observers[device.serial] = service.objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                next[device.serial] = service
            }
        }
        services = next
        serviceObservers = observers
    }

    private func wireCloud() {
        cloud.onReport = { [weak self] serial, print in
            guard let self else { return }
            if let service = self.services[serial] {
                service.ingest(print: print)
            }
        }
        cloud.onConnectionChanged = { [weak self] connected in
            self?.cloudConnected = connected
        }
        cloud.onAuthFailure = { [weak self] in
            guard let self else { return }
            self.cloud.stop()
            self.cloudConnected = false
            self.authStep = .login
            self.authMessage = "云端认证失败，请重新登录"
            SessionStore.clear()
            self.session = nil
        }
    }

    // MARK: - Notifications

    private func handleTransition(status: PrinterStatus, old: PrintState, new: PrintState, service: PrinterService) {
        Log.write("State \(service.device.name): \(old.rawValue) -> \(new.rawValue)")
        guard notificationsEnabled else { return }
        if new == .finished {
            NotificationManager.shared.notify(
                title: "打印完成 · \(service.device.name)",
                body: status.displayName
            )
        } else if new == .failed {
            NotificationManager.shared.notify(
                title: "打印异常 · \(service.device.name)",
                body: "请检查打印机状态" + (status.printError != 0 ? "（错误码 \(status.printError)）" : "")
            )
        }
    }

    // MARK: - Settings

    func setManualIP(_ ip: String, for serial: String) {
        var copy = manualIPs
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { copy.removeValue(forKey: serial) } else { copy[serial] = trimmed }
        manualIPs = copy
    }

    private func persistManualIPs() {
        if let data = try? JSONEncoder().encode(manualIPs) {
            UserDefaults.standard.set(data, forKey: Keys.manualIPs)
        }
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            authMessage = "无法设置开机启动：\(error.localizedDescription)"
            Log.write("SMAppService error: \(error.localizedDescription)")
        }
    }

    func refreshAll() {
        for service in services.values { service.refresh() }
        refreshDevices()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                for service in strongSelf.services.values {
                    service.markOfflineIfStale()
                }
                strongSelf.objectWillChange.send()
            }
        }
    }
}
