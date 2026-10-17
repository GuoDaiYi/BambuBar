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

/// App-wide coordinator: cloud session, printer list, language, update checks
/// and the periodic freshness timer for all printer services.
@MainActor
final class AppModel: ObservableObject {
    @Published var session: CloudSession?
    @Published var devices: [CloudDevice] = []
    @Published var services: [String: PrinterService] = [:]
    @Published var selectedID: String {
        didSet {
            if !selectedID.isEmpty, !isDemo {
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
            guard !isDemo else { return }
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
            if notificationsEnabled { NotificationManager.shared.request() }
        }
    }
    @Published var launchAtLogin: Bool = false
    @Published var loginRegion: CloudRegion {
        didSet { if !isDemo { UserDefaults.standard.set(loginRegion.rawValue, forKey: Keys.region) } }
    }
    @Published var language: AppLanguage {
        didSet {
            Lang.current = language
            if !isDemo {
                UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            }
        }
    }
    @Published var lastRefresh: Date?
    @Published var availableUpdate: UpdateInfo?
    /// When true, the main popover shows the merged Settings view.
    @Published var showSettings = false

    private let api = CloudAPI()
    private let cloud = BambuCloud()
    private var pendingAccount = ""
    private var ticker: Timer?
    private var bootstrapped = false
    private var serviceObservers: [String: AnyCancellable] = [:]
    private var isDemo = false
    private var checkingUpdate = false

    private enum Keys {
        static let selected = "selectedPrinter"
        static let notifications = "notificationsEnabled"
        static let region = "loginRegion"
        static let account = "loginAccount"
        static let language = "appLanguage"
        static let updateCheck = "lastUpdateCheck"
        static let updateNotified = "lastUpdateNotified"
    }

    init(startNetwork: Bool = true) {
        selectedID = UserDefaults.standard.string(forKey: Keys.selected) ?? ""
        let savedLanguage = UserDefaults.standard.string(forKey: Keys.language)
        let initialLanguage = AppLanguage(rawValue: savedLanguage ?? "") ?? AppLanguage.systemDefault()
        language = initialLanguage
        Lang.current = initialLanguage
        notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notifications) as? Bool ?? true
        let regionRaw = UserDefaults.standard.string(forKey: Keys.region) ?? CloudRegion.china.rawValue
        loginRegion = CloudRegion(rawValue: regionRaw) ?? .china
        pendingAccount = UserDefaults.standard.string(forKey: Keys.account) ?? ""
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

    static func demo(language: AppLanguage = .zhHans) -> AppModel {
        let app = AppModel(startNetwork: false)
        app.isDemo = true
        app.language = language
        let mainDevice = CloudDevice(
            serial: "01S00A000000001",
            name: Lang.t("A1 · 工作台", "A1 · Studio"),
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
        s.jobName = Lang.t("Cyber Dragon · 分件套", "Cyber Dragon · Kit")
        s.gcodeFile = "cyber_dragon_plate_2.gcode.3mf"
        s.wifiSignal = -48
        s.printError = 0
        s.stage = 0
        s.lastUpdate = Date()

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
        app.loginRegion = .china
        app.notificationsEnabled = true
        app.launchAtLogin = false
        app.serviceObservers = [:]
        app.selectedID = mainDevice.serial
        app.cloudConnected = true
        app.authStep = .ready
        app.isWorking = false
        return app
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
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
        if !service.isOnline { return Lang.t("离线", "Offline") }
        switch status.state {
        case .running, .prepare: return "\(status.progress)%"
        case .paused: return Lang.t("暂停", "Pause")
        case .finished: return Lang.t("完成", "Done")
        case .failed: return Lang.t("异常", "Error")
        case .idle: return Lang.t("待机", "Idle")
        case .offline: return Lang.t("离线", "Offline")
        case .unknown: return Lang.t("等待", "Wait")
        }
    }

    // MARK: - Bootstrap / auth

    /// Restores a saved cloud session and loads the bound printers on launch.
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
            authMessage = Lang.t("登录已过期，请重新登录", "Your session expired. Please sign in again.")
            return
        }
        session = existing
        authStep = .loading
        let valid = await api.isSessionValid(existing)
        if !valid {
            SessionStore.clear()
            session = nil
            authStep = .login
            authMessage = Lang.t("登录已过期，请重新登录", "Your session expired. Please sign in again.")
            return
        }
        await loadDevices(startCloud: true)
    }

    func login(account: String, password: String) {
        guard !isWorking else { return }
        let account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !password.isEmpty else {
            authMessage = Lang.t("请输入账号和密码", "Enter your account and password.")
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
                    authMessage = Lang.t("验证码已发送到你的邮箱或手机，请输入 6 位验证码",
                                        "A verification code was sent to your email or phone. Enter the 6-digit code.")
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
            authMessage = Lang.t("请输入邮箱或短信验证码", "Enter the email or SMS verification code.")
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
        showSettings = false
        authStep = .login
        authMessage = nil
    }

    func refreshDevices() {
        guard session != nil else { return }
        Task { await loadDevices(startCloud: true) }
    }

    /// Fetches bound devices and creates/updates one `PrinterService` per device.
    private func loadDevices(startCloud: Bool) async {
        guard let session else { return }
        do {
            let fetched = try await api.fetchDevices(session: session)
            devices = fetched
            syncServices(with: fetched)
            lastRefresh = Date()
            if fetched.isEmpty {
                authStep = .empty
                authMessage = Lang.t("这个账号下还没有绑定打印机", "No printers are bound to this account.")
                cloud.stop()
                cloudConnected = false
                return
            }
            authStep = .ready
            checkForUpdates()
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
            authMessage = Lang.t("登录已过期，请重新登录", "Your session expired. Please sign in again.")
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

    // MARK: - Update check

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.1"
    }

    /// Checks the public GitHub Releases API at most once every six hours.
    /// A small badge is shown when a newer version exists.
    func checkForUpdates(force: Bool = false) {
        guard !isDemo, !checkingUpdate else { return }
        let last = UserDefaults.standard.object(forKey: Keys.updateCheck) as? Date ?? .distantPast
        if !force, Date().timeIntervalSince(last) < 6 * 60 * 60 { return }
        checkingUpdate = true
        UserDefaults.standard.set(Date(), forKey: Keys.updateCheck)
        let current = appVersion
        Task {
            let update = await UpdateChecker.fetchLatest(currentVersion: current)
            checkingUpdate = false
            availableUpdate = update
            guard let update else { return }
            let notified = UserDefaults.standard.string(forKey: Keys.updateNotified)
            if notified != update.version, notificationsEnabled {
                UserDefaults.standard.set(update.version, forKey: Keys.updateNotified)
                NotificationManager.shared.notify(
                    title: Lang.t("BambuBar \(update.version) 可用", "BambuBar \(update.version) is available"),
                    body: Lang.t("点击菜单栏中的更新提示前往下载。", "Open the update badge in the menu bar panel to download it.")
                )
            }
        }
    }

    func openUpdate() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.url)
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
            self.authMessage = Lang.t("云端认证失败，请重新登录", "Cloud authentication failed. Please sign in again.")
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
                title: Lang.t("打印完成 · \(service.device.name)", "Print finished · \(service.device.name)"),
                body: status.displayName
            )
        } else if new == .failed {
            NotificationManager.shared.notify(
                title: Lang.t("打印异常 · \(service.device.name)", "Print error · \(service.device.name)"),
                body: Lang.t("请检查打印机状态", "Check the printer status")
                    + (status.printError != 0 ? Lang.t("（错误码 \(status.printError)）", " (error \(status.printError))") : "")
            )
        }
    }

    // MARK: - Settings

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
            authMessage = Lang.t("无法设置开机启动：\(error.localizedDescription)",
                                "Could not update launch at login: \(error.localizedDescription)")
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
