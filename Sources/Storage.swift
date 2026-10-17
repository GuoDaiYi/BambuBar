import Foundation
import Security

enum SessionStore {
    private static let service = "com.local.bambubar"
    private static let account = "cloud-session"
    private static let fallbackURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("BambuBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }()

    static func save(_ session: CloudSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            Log.write("keychain save failed (\(status)); falling back to file")
            try? data.write(to: fallbackURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fallbackURL.path)
        } else {
            try? FileManager.default.removeItem(at: fallbackURL)
        }
    }

    static func load() -> CloudSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let session = try? JSONDecoder().decode(CloudSession.self, from: data) {
            return session
        }
        if let data = try? Data(contentsOf: fallbackURL),
           let session = try? JSONDecoder().decode(CloudSession.self, from: data) {
            return session
        }
        return nil
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        try? FileManager.default.removeItem(at: fallbackURL)
    }
}
