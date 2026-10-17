import Foundation

struct UpdateInfo: Identifiable, Equatable {
    let version: String
    let url: URL
    var id: String { version }
}

/// Lightweight check against the public GitHub Releases API.
/// No token is used and failures are intentionally silent.
enum UpdateChecker {
    static func fetchLatest(currentVersion: String) async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/GuoDaiYi/BambuBar/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BambuBar-UpdateCheck", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let html = json["html_url"] as? String,
              let releaseURL = URL(string: html) else {
            return nil
        }

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard isNewer(latest, than: currentVersion) else { return nil }
        return UpdateInfo(version: latest, url: releaseURL)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
