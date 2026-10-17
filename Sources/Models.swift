import Foundation

// MARK: - Region

enum CloudRegion: String, Codable, CaseIterable, Identifiable {
    case china
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .china: return "中国区"
        case .global: return "国际区"
        }
    }

    var apiBase: String {
        switch self {
        case .china: return "https://api.bambulab.cn"
        case .global: return "https://api.bambulab.com"
        }
    }

    var mqttHost: String {
        switch self {
        case .china: return "cn.mqtt.bambulab.com"
        case .global: return "us.mqtt.bambulab.com"
        }
    }
}

// MARK: - Session

struct CloudSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var uid: String
    var region: CloudRegion
    var account: String
    var expiresAt: Date

    var isExpired: Bool { expiresAt.timeIntervalSinceNow < 60 }
}

// MARK: - Device

struct CloudDevice: Identifiable, Codable, Hashable {
    var serial: String
    var name: String
    var model: String
    var accessCode: String
    var online: Bool
    var nozzleDiameter: String?

    var id: String { serial }

    var shortName: String {
        if name.count <= 14 { return name }
        return String(name.prefix(13)) + "…"
    }

    init(serial: String, name: String, model: String, accessCode: String, online: Bool, nozzleDiameter: String? = nil) {
        self.serial = serial
        self.name = name
        self.model = model
        self.accessCode = accessCode
        self.online = online
        self.nozzleDiameter = nozzleDiameter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serial = try c.decodeIfPresent(String.self, forKey: .serial) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "打印机"
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        accessCode = (try c.decodeIfPresent(String.self, forKey: .accessCode) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        online = try c.decodeIfPresent(Bool.self, forKey: .online) ?? false
        nozzleDiameter = try c.decodeIfPresent(String.self, forKey: .nozzleDiameter)
    }

    enum CodingKeys: String, CodingKey {
        case serial, name, model, accessCode, online, nozzleDiameter
    }
}

extension CloudDevice {
    /// Parses a device out of the raw /user/bind response.
    init?(json: [String: Any]) {
        guard let serial = json["dev_id"] as? String, serial.count > 4 else { return nil }
        let name = (json["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "打印机"
        var model = (json["dev_product_name"] as? String)
            ?? (json["dev_model_name"] as? String)
            ?? ""
        if model.isEmpty { model = "Bambu Lab" }
        model = Self.prettyModel(model)
        let code = ((json["dev_access_code"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let online = (json["online"] as? Bool) ?? ((json["online"] as? NSNumber)?.boolValue ?? false)
        let nozzle = json["nozzle_diameter"] as? String
        self.init(serial: serial, name: name, model: model, accessCode: code, online: online, nozzleDiameter: nozzle)
    }

    static func prettyModel(_ raw: String) -> String {
        let map: [String: String] = [
            "BL-P001": "X1 Carbon", "BL-P002": "X1", "C11": "P1P", "C12": "P1S",
            "C13": "X1E", "N1": "A1 mini", "N2S": "A1", "O1D": "H2D",
            "O1E": "H2D Pro", "O1C": "X2D", "O1C2": "X2D", "N7": "P2S",
            "N9": "H2C", "BL-P003": "X1"
        ]
        if let m = map[raw] { return m }
        return raw
    }
}

// MARK: - Print state

enum PrintState: String, Codable {
    case idle
    case prepare
    case running
    case paused
    case finished
    case failed
    case offline
    case unknown

    init(gcode: String?) {
        switch (gcode ?? "").uppercased() {
        case "IDLE": self = .idle
        case "PREPARE": self = .prepare
        case "RUNNING": self = .running
        case "PAUSE", "PAUSED": self = .paused
        case "FINISH", "FINISHED": self = .finished
        case "FAILED", "FAIL": self = .failed
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .idle: return "空闲"
        case .prepare: return "准备中"
        case .running: return "打印中"
        case .paused: return "已暂停"
        case .finished: return "已完成"
        case .failed: return "失败"
        case .offline: return "离线"
        case .unknown: return "未知"
        }
    }

    var shortLabel: String {
        switch self {
        case .idle: return "待机"
        case .prepare: return "准备"
        case .running: return "打印"
        case .paused: return "暂停"
        case .finished: return "完成"
        case .failed: return "异常"
        case .offline: return "离线"
        case .unknown: return "未知"
        }
    }

    var isBusy: Bool {
        self == .running || self == .prepare || self == .paused
    }

    var canPause: Bool {
        self == .running || self == .prepare
    }

    var canResume: Bool {
        self == .paused
    }
}

// MARK: - AMS

struct AMSTray: Identifiable, Hashable {
    var id: Int
    var slot: Int
    var type: String
    var colorHex: String
    var remain: Int?
    var brand: String
    var name: String
    var isExternal: Bool
    var isActive: Bool

    var isEmpty: Bool { type.isEmpty }
    var displayType: String { type.isEmpty ? "空" : type }

    var remainText: String {
        guard let r = remain, r >= 0 else { return "—" }
        return "\(r)%"
    }

    init(id: Int, slot: Int, type: String, colorHex: String, remain: Int?,
         brand: String = "", name: String = "", isExternal: Bool = false, isActive: Bool = false) {
        self.id = id
        self.slot = slot
        self.type = type
        self.colorHex = colorHex
        self.remain = remain
        self.brand = brand
        self.name = name
        self.isExternal = isExternal
        self.isActive = isActive
    }

    init?(json: [String: Any], slot: Int, isActive: Bool, isExternal: Bool) {
        let type = (json["tray_type"] as? String) ?? ""
        let color = (json["tray_color"] as? String) ?? (json["cols"] as? [String])?.first ?? "808080FF"
        if type.isEmpty && !isExternal { return nil }
        self.id = isExternal ? 254 : slot
        self.slot = slot
        self.type = type
        self.colorHex = color
        var r = Parse.intValue(json["remain"])
        if let rr = r, rr < 0 { r = nil }
        self.remain = r
        self.brand = (json["tray_sub_brands"] as? String) ?? ""
        self.name = (json["tray_id_name"] as? String) ?? ""
        self.isExternal = isExternal
        self.isActive = isActive
    }
}

struct HMSItem: Identifiable, Hashable {
    var code: Int
    var attr: Int
    var module: Int

    var id: String { "\(attr)-\(code)-\(module)" }

    var description: String {
        "HMS \(String(format: "%04X", attr))-\(String(format: "%04X", code))"
    }

    init?(json: [String: Any]) {
        let c = Parse.intValue(json["code"]) ?? -1
        let a = Parse.intValue(json["attr"]) ?? 0
        let m = Parse.intValue(json["module"]) ?? 0
        if c < 0 { return nil }
        code = c; attr = a; module = m
    }
}

// MARK: - Status

struct PrinterStatus {
    var state: PrintState = .unknown
    var gcodeStateRaw: String = ""
    var progress: Int = 0
    var remainingMinutes: Int = 0
    var layer: Int = 0
    var totalLayers: Int = 0
    var speedLevel: Int = 2
    var speedMagnitude: Int = 100
    var nozzleTemp: Double = 0
    var nozzleTarget: Double = 0
    var bedTemp: Double = 0
    var bedTarget: Double = 0
    var chamberTemp: Double?
    var coolingFan: Int = 0
    var auxFan: Int = 0
    var chamberFan: Int = 0
    var jobName: String = ""
    var gcodeFile: String = ""
    var wifiSignal: Int?
    var amsTrays: [AMSTray] = []
    var externalTray: AMSTray?
    var amsHumidity: Int?
    var amsTemp: Double?
    var activeTray: Int?
    var ipAddress: String?
    var cameraAvailable: Bool = false
    var hms: [HMSItem] = []
    var printError: Int = 0
    var stage: Int = -1
    var lightOn: Bool?
    var lastUpdate: Date?
    var printStartedAt: Date?
    var totalTimeMinutes: Int = 0

    var hasAMS: Bool { !amsTrays.isEmpty || externalTray != nil }
    var displayName: String {
        if !jobName.isEmpty { return jobName }
        if !gcodeFile.isEmpty { return gcodeFile }
        return "没有正在打印的任务"
    }

    var remainingText: String {
        guard remainingMinutes > 0 else { return "—" }
        let h = remainingMinutes / 60
        let m = remainingMinutes % 60
        if h > 0 { return "\(h) 小时 \(m) 分" }
        return "\(m) 分钟"
    }

    var etaText: String? {
        guard state.isBusy, remainingMinutes > 0 else { return nil }
        let date = Date().addingTimeInterval(TimeInterval(remainingMinutes * 60))
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    var layerText: String {
        guard totalLayers > 0 else { return "—" }
        return "\(max(layer, 0)) / \(totalLayers)"
    }

    var stageText: String {
        if state == .finished { return "打印完成" }
        if state == .failed { return "打印异常" }
        if state == .paused { return "已暂停" }
        if state == .idle { return "准备就绪" }
        if state == .prepare { return "正在准备" }
        let codes: [Int: String] = [
            0: "打印中", 1: "自动调平", 2: "热床预热", 3: "振动补偿", 4: "更换耗材",
            5: "暂停", 6: "用户暂停", 7: "前门打开", 8: "耗材用尽", 9: "喷嘴升温",
            10: "热床升温", 11: "校准中", 12: "扫描热床", 13: "空闲", 14: "挤出校准",
            15: "冷却中", 16: "暂停", 17: "装填耗材", 18: "电机降噪", 19: "校准中",
            20: "检测中", 21: "清洁喷嘴", 22: "调平热床", 23: "预热中", 24: "打印中",
            25: "换料中", 26: "暂停中", 27: "扫描中", 28: "检查中"
        ]
        return codes[stage] ?? (state == .unknown ? "等待数据" : state.label)
    }

    var speedLabel: String {
        switch speedLevel {
        case 1: return "静音"
        case 2: return "标准"
        case 3: return "运动"
        case 4: return "狂暴"
        default: return "标准"
        }
    }

    var etaLine: String {
        if !etaText.isEmptyOrNil {
            return "预计 \(etaText ?? "") 完成"
        }
        return state.isBusy ? "计算剩余时间…" : "等待任务"
    }

    mutating func apply(report p: [String: Any], now: Date = Date()) {
        lastUpdate = now

        if let raw = p["gcode_state"] as? String {
            gcodeStateRaw = raw
            let newState = PrintState(gcode: raw)
            if newState == .running && state != .running {
                printStartedAt = now
            }
            if newState == .finished || newState == .failed || newState == .idle {
                if newState == .idle || newState == .finished { /* keep progress for finished */ }
            }
            state = newState
        }

        if let v = Parse.intValue(p["mc_percent"]) { progress = min(max(v, 0), 100) }
        if let v = Parse.intValue(p["mc_remaining_time"]) { remainingMinutes = max(v, 0) }
        if let v = Parse.intValue(p["layer_num"]) { layer = v }
        if let v = Parse.intValue(p["total_layer_num"]) { totalLayers = v }
        if let v = Parse.intValue(p["spd_lvl"]) { speedLevel = v }
        if let v = Parse.intValue(p["spd_mag"]) { speedMagnitude = v }
        if let v = Parse.doubleValue(p["nozzle_temper"]) { nozzleTemp = v }
        if let v = Parse.doubleValue(p["nozzle_target_temper"]) { nozzleTarget = v }
        if let v = Parse.doubleValue(p["bed_temper"]) { bedTemp = v }
        if let v = Parse.doubleValue(p["bed_target_temper"]) { bedTarget = v }
        if let v = Parse.doubleValue(p["chamber_temper"]), v > -50 { chamberTemp = v }
        if let v = Parse.intValue(p["cooling_fan_speed"]) { coolingFan = Self.fanPercent(v) }
        if let v = Parse.intValue(p["big_fan1_speed"]) { auxFan = Self.fanPercent(v) }
        if let v = Parse.intValue(p["big_fan2_speed"]) { chamberFan = Self.fanPercent(v) }

        if let v = p["subtask_name"] as? String, !v.isEmpty { jobName = Self.cleanName(v) }
        if let v = p["gcode_file"] as? String, !v.isEmpty { gcodeFile = Self.cleanName(v) }
        if jobName.isEmpty, !gcodeFile.isEmpty { jobName = gcodeFile }

        if let ws = p["wifi_signal"] as? String {
            wifiSignal = Int(ws.replacingOccurrences(of: "dBm", with: ""))
        } else if let wi = Parse.intValue(p["wifi_signal"]) {
            wifiSignal = wi
        }

        if let e = Parse.intValue(p["print_error"]) { printError = e }
        if let s = Parse.intValue(p["stg_cur"]) { stage = s }

        if let ams = p["ams"] as? [String: Any], let units = ams["ams"] as? [[String: Any]] {
            let active = Parse.intValue(ams["tray_now"])
            var trays: [AMSTray] = []
            for unit in units {
                let unitID = Parse.intValue(unit["id"]) ?? 0
                if let hum = Parse.intValue(unit["humidity"]) { amsHumidity = hum }
                if let temp = Parse.doubleValue(unit["temp"]) { amsTemp = temp }
                let list = (unit["tray"] as? [[String: Any]]) ?? []
                for t in list {
                    let trayID = Parse.intValue(t["id"]) ?? 0
                    let slot = unitID * 4 + trayID
                    let isActive = active == slot
                    if let tray = AMSTray(json: t, slot: slot, isActive: isActive, isExternal: false) {
                        trays.append(tray)
                    }
                }
            }
            if !trays.isEmpty || !units.isEmpty { amsTrays = trays }
            activeTray = active
        }

        if let vt = p["vt_tray"] as? [String: Any] {
            let active = activeTray == 254
            externalTray = AMSTray(json: vt, slot: 254, isActive: active, isExternal: true)
        }

        if let ipcam = p["ipcam"] as? [String: Any] {
            cameraAvailable = (ipcam["ipcam_dev"] as? String) == "1"
        }

        if let net = p["net"] as? [String: Any],
           let infos = net["info"] as? [[String: Any]],
           let info = infos.first {
            if let raw = Parse.intValue(info["ip"]) {
                ipAddress = Self.ipString(raw)
            }
        } else if let ip = p["ip"] as? String, !ip.isEmpty {
            ipAddress = ip
        }

        if let hmsList = p["hms"] as? [[String: Any]] {
            hms = hmsList.compactMap(HMSItem.init(json:))
        }

        if let lights = p["lights_report"] as? [[String: Any]],
           let light = lights.first(where: { ($0["node"] as? String) == "chamber_light" }) {
            lightOn = (light["mode"] as? String) == "on"
        }

        if let total = Parse.intValue(p["total_print_time"]), total > 0 {
            totalTimeMinutes = total
        }
    }

    mutating func markStale() {
        if state != .offline {
            state = .offline
        }
    }

    static func fanPercent(_ raw: Int) -> Int {
        if raw <= 100 { return max(0, min(100, raw)) }
        return max(0, min(100, Int((Double(raw) / 255.0 * 100.0).rounded())))
    }

    static func ipString(_ raw: Int) -> String {
        let v = UInt32(bitPattern: Int32(truncatingIfNeeded: raw))
        return "\(v & 0xFF).\((v >> 8) & 0xFF).\((v >> 16) & 0xFF).\((v >> 24) & 0xFF)"
    }

    static func cleanName(_ name: String) -> String {
        var n = name
        for suffix in [".gcode.3mf", ".gcode", ".3mf", ".stl"] where n.lowercased().hasSuffix(suffix) {
            n = String(n.dropLast(suffix.count))
        }
        return n
    }
}

// MARK: - Parsing helpers

enum Parse {
    static func intValue(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String {
            if let i = Int(s) { return i }
            if let d = Double(s) { return Int(d) }
        }
        return nil
    }

    static func doubleValue(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}

extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        guard let self else { return true }
        return self.isEmpty
    }
}
