import Foundation

enum CloudError: LocalizedError {
    case badResponse
    case unauthorized
    case server(String)
    case missingUID
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .badResponse: return Lang.t("服务器返回了无法识别的数据", "The server returned an unrecognized response.")
        case .unauthorized: return Lang.t("登录已过期，请重新登录", "Your session expired. Please sign in again.")
        case .server(let msg): return msg
        case .missingUID: return Lang.t("无法获取用户 ID，请重新登录", "Could not retrieve your user ID. Please sign in again.")
        case .decode(let msg): return Lang.t("数据解析失败：\(msg)", "Could not parse the response: \(msg)")
        }
    }
}

enum LoginOutcome {
    case loggedIn(CloudSession)
    case needsCode
}

/// Thin Bambu Cloud REST client used for login, token/UID lookup and devices.
final class CloudAPI {
    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Language": "zh-CN,zh;q=0.9"
        ]
        urlSession = URLSession(configuration: config)
    }

    // MARK: - Login

    func login(account: String, password: String, region: CloudRegion) async throws -> LoginOutcome {
        let body: [String: Any] = [
            "account": account,
            "password": password,
            "apiError": ""
        ]
        let json: [String: Any]
        do {
            json = try await post(path: "/v1/user-service/user/login", region: region, body: body, token: nil)
        } catch CloudError.server(let message)
                    where message.lowercased().contains("verif") || message.contains("验证码") {
            return .needsCode
        }
        if let token = json["accessToken"] as? String, !token.isEmpty {
            let refresh = (json["refreshToken"] as? String) ?? token
            let expiresIn = Parse.doubleValue(json["expiresIn"]) ?? 7_776_000
            var uid = Self.uid(from: json)
            if uid == nil {
                uid = try await fetchUID(token: token, region: region)
            }
            guard let uid, !uid.isEmpty else { throw CloudError.missingUID }
            let session = CloudSession(
                accessToken: token,
                refreshToken: refresh,
                uid: uid,
                region: region,
                account: account,
                expiresAt: Date().addingTimeInterval(expiresIn)
            )
            return .loggedIn(session)
        }
        if (json["loginType"] as? String) == "verifyCode" {
            return .needsCode
        }
        let msg = (json["error"] as? String) ?? (json["message"] as? String) ?? Lang.t("登录失败，请检查账号和密码", "Sign-in failed. Check your account and password.")
        throw CloudError.server(msg)
    }

    func loginWithCode(account: String, code: String, region: CloudRegion) async throws -> CloudSession {
        let body: [String: Any] = [
            "account": account,
            "code": code,
            "apiError": ""
        ]
        let json = try await post(path: "/v1/user-service/user/login", region: region, body: body, token: nil)
        guard let token = json["accessToken"] as? String, !token.isEmpty else {
            let msg = (json["error"] as? String) ?? (json["message"] as? String)
                ?? Lang.t("验证码校验失败，请重新获取", "The verification code was rejected. Request a new one.")
            throw CloudError.server(msg)
        }
        let refresh = (json["refreshToken"] as? String) ?? token
        let expiresIn = Parse.doubleValue(json["expiresIn"]) ?? 7_776_000
        var uid = Self.uid(from: json)
        if uid == nil {
            uid = try await fetchUID(token: token, region: region)
        }
        guard let uid, !uid.isEmpty else { throw CloudError.missingUID }
        return CloudSession(
            accessToken: token,
            refreshToken: refresh,
            uid: uid,
            region: region,
            account: account,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    // MARK: - Account / devices

    func fetchUID(token: String, region: CloudRegion) async throws -> String? {
        if let uid = Self.uidFromJWT(token) { return uid }
        do {
            let json = try await get(path: "/v1/design-user-service/my/preference", region: region, token: token)
            if let uid = Self.uid(from: json) { return uid }
        } catch {
            Log.write("preference failed: \(error.localizedDescription)")
        }
        return Self.uidFromJWT(token)
    }

    func fetchProfileName(token: String, region: CloudRegion) async -> String? {
        guard let json = try? await get(path: "/v1/design-user-service/my/preference", region: region, token: token) else {
            return nil
        }
        return (json["name"] as? String) ?? (json["handle"] as? String)
    }

    func fetchDevices(session: CloudSession) async throws -> [CloudDevice] {
        let json = try await get(path: "/v1/iot-service/api/user/bind", region: session.region, token: session.accessToken)
        let list = (json["devices"] as? [[String: Any]]) ?? []
        return list.compactMap(CloudDevice.init(json:))
    }

    func refreshDeviceList(session: CloudSession) async throws -> [CloudDevice] {
        try await fetchDevices(session: session)
    }

    /// Returns true when the token is still accepted by the cloud.
    func isSessionValid(_ session: CloudSession) async -> Bool {
        do {
            _ = try await get(path: "/v1/iot-service/api/user/bind", region: session.region, token: session.accessToken)
            return true
        } catch CloudError.unauthorized {
            return false
        } catch {
            // Network problems are not an auth failure.
            return true
        }
    }

    // MARK: - HTTP

    private func headers(token: String?) -> [String: String] {
        var h: [String: String] = [
            "Content-Type": "application/json",
            "User-Agent": "bambu_network_agent/02.08.02.61",
            "X-BBL-Client-Type": "slicer",
            "X-BBL-Client-Name": "BambuStudio",
            "X-BBL-Client-Version": "02.08.02.61",
            "X-BBL-Language": "zh-CN",
            "X-BBL-OS-Type": "macos"
        ]
        if let token { h["Authorization"] = "Bearer \(token)" }
        return h
    }

    private func get(path: String, region: CloudRegion, token: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: region.apiBase + path)!)
        request.httpMethod = "GET"
        for (k, v) in headers(token: token) { request.setValue(v, forHTTPHeaderField: k) }
        return try await perform(request)
    }

    private func post(path: String, region: CloudRegion, body: [String: Any], token: String?) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: region.apiBase + path)!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        for (k, v) in headers(token: token) { request.setValue(v, forHTTPHeaderField: k) }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw CloudError.server(Lang.t("网络请求失败：\(error.localizedDescription)", "Network request failed: \(error.localizedDescription)"))
        }
        guard let http = response as? HTTPURLResponse else { throw CloudError.badResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if http.statusCode == 401 || http.statusCode == 403 {
            throw CloudError.unauthorized
        }
        if http.statusCode >= 400 {
            let msg = (json["error"] as? String) ?? (json["message"] as? String)
                ?? Lang.t("服务器错误（HTTP \(http.statusCode)）", "Server error (HTTP \(http.statusCode))")
            if msg.lowercased().contains("incorrect account or password") {
                throw CloudError.server(Lang.t("账号或密码错误", "Incorrect account or password."))
            }
            if msg.lowercased().contains("verify code") {
                throw CloudError.server(Lang.t("需要邮箱或短信验证码", "A verification code is required."))
            }
            throw CloudError.server(msg)
        }
        if json["accessToken"] is String { return json }
        if let message = json["message"] as? String, message.lowercased() != "success", json["error"] != nil {
            throw CloudError.server(message)
        }
        return json
    }

    // MARK: - UID helpers

    private static func uid(from json: [String: Any]) -> String? {
        for key in ["uid", "user_id", "userId", "userID"] {
            if let s = json[key] as? String, !s.isEmpty { return s }
            if let n = json[key] as? NSNumber { return n.stringValue }
        }
        if let user = json["user"] as? [String: Any] { return uid(from: user) }
        return nil
    }

    private static func uidFromJWT(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        for key in ["uid", "user_id", "userId", "sub"] {
            if let s = json[key] as? String, !s.isEmpty, s.allSatisfy({ $0.isNumber }) { return s }
            if let n = json[key] as? NSNumber { return n.stringValue }
        }
        return nil
    }
}
